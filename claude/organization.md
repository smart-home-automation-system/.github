# Smart Home Automation System — organization context

Solo-developer project: a set of repositories under the GitHub organization
[smart-home-automation-system](https://github.com/smart-home-automation-system) that together
control a real smart home — an AMX/NetLinx control system with Eaton wireless devices, and
Shelly Wi-Fi devices. The backend runs on a Kubernetes cluster. All repositories are public
except `deployment-tools`.

## What belongs in this file

This file is loaded into **every** session, so it holds only what crosses repositories: the
map of the repositories, the contracts between them, and the rules every repository follows.
**What one service, library or the dashboard does in detail belongs to its own `CLAUDE.md`
and README**, not here — a task adds at most a line to its row below and writes the rest
there. Claude Code refuses a file above 150k characters; keep this one around 60k.
The full history of the decisions summarised here is in `claude/history.md` (an archive of
2026-10-14, not imported) — read it when the history of a decision matters.

## Repository map

### Spring Boot microservices (all reactive — WebFlux)

| Repository | Local port | Purpose | Release |
|---|---|---|---|
| `api-gateway-service` | 6200 | Spring Cloud Gateway — the **only** entry point into the cluster from outside; static routes to the services over k8s DNS (see External traffic) | **0.5.0** (2026-10-13, HAS-225) |
| `amx-service` | 6001 | Bridge to the AMX control system over **one permanent TCP socket to the frame server of the Television master** (port 20010, NetLinx side HAS-230): receives every Eaton frame of both gateways and publishes the readings, **sends** Eaton frames (blinds, lights, levels) the other way; publishes what an Eaton blinds, light, dimmer, push button or PIR sensor reports as `DeviceEvent` to `/device` (HAS-229, HAS-288); `POST /home/amx` is gone since 2.0.0 (HAS-286) | **2.2.0** (2026-10-15, HAS-288) |
| `heating-service` | 6002 | Heating control; watches the temperature sensors (an alert after 24 h of silence); serves the rooms, the floor pump and the stored temperature history read-only — the contract of the dashboard | **1.9.2** |
| `notification-service` | 6003 | Consumes the `alert` and `info` queues and posts each message to the Discord channel `alerts` as an embed coloured by its level — two listener containers on purpose (HAS-179) | **0.4.4** |
| `ai-service` | 6004 | AI integration (Spring AI 2.0 `ChatClient`, OpenAI) | **0.2.1** |
| `database-service` | 6005 | Persistence facade: the household registry (members, devices, roles, rooms, permissions; the profiles of the dashboard), the **device registry** of every device of the house (read and written; the Eaton configuration `amx-service` asks for is served from it) and the **calendar of the house** (days off) | **0.15.0** (2026-10-15, HAS-288) |
| `water-service` | 6006 | Hot water: reads a Shelly Uni every 3 min, keeps the flag `boiler-service` polls (on below 38 °C, off above 42), serves the dated reading and the stored history | **0.6.0** |
| `boiler-service` | 6007 | Drives the furnace and both pumps as relays of one Shelly Pro 4; alerts when that Shelly stops answering (HAS-109) | **1.3.2** |
| `shelly-cloud-service` | 6008 | Shelly cloud integration — a **skeleton** (Actuator only, no endpoints) | **0.1.1** |
| `presence-service` | 6009 | Household presence: UniFi clients matched against the household registry every minute, status changes stored, four routed reports, nightly retention (`P365D`). State in the memory of one instance: `Recreate`, never scaled | **0.6.0** |
| `blinds-service` | 6011 | Roller shutters (epic HAS-242): Eaton blinds through `amx-service`, Shelly blinds, the real state, weather-aware schedules. Knows the blinds from the device registry (every 5 min) and moves them on command through three drivers - Shelly Gen1 roller, Shelly Gen2 cover, Eaton through `amx-service` (HAS-244); `POST /home/blinds/{id}`, `/{id}/position`, `/rooms/{room}`. Tracks the real state of every blind (HAS-245): Gen2 covers from `device.prod.blinds` (MQTT) plus `Cover.GetStatus` every 5 min, Gen1 rollers by `/status` every 60 s and their `roller_*_url` actions on `GET /home/blinds/events/gen1`, Eaton from the `status` events of `amx-service`; table `blinds_state`; `GET /home/blinds`, `/rooms/{room}`, `/{id}`. Nothing routed yet (HAS-251 must include `/events/gen1`). Own database, `Recreate`, never scaled | **0.3.0** (2026-10-15, HAS-245) |

Do not confuse `api-gateway-service` (HTTP edge) with `amx-service` (AMX hardware bridge).

### Shared libraries (Maven, `cloud.cholewa` group)

| Library | Purpose | Current consumers | Latest |
|---|---|---|---|
| `cholewa-commons` | Common utilities: the error contract, the pooled R2DBC factory, English validation messages, the RabbitMQ connection name, `NotificationPublisher` | ai, amx, api-gateway, blinds, boiler, database, heating, notification, presence, shelly-cloud, water | **1.8.0** |
| `cholewa-security` | Security/auth | none yet — kept for possible future auth in `api-gateway-service` | **1.0.0** |
| `smart-home-sdk` | Shared domain / API models (household, device registry, calendar, device events) | amx, blinds, boiler, database, heating, presence, shelly-cloud, water | **1.9.0** |
| `shelly-client` | Models of what a Shelly answers and publishes, reactive HTTP clients (Gen2+ RPC, Gen1) and the MQTT decoder | blinds (2.0.0); boiler, heating, shelly-cloud, water (still on 1.0.0) | **2.0.0** |

Versions in the services (2026-10-15): `cholewa-commons` 1.8.0 on amx, api-gateway, blinds,
boiler, database, heating, notification; 1.7.0 on ai, shelly-cloud, water; 1.5.1 on presence.
`smart-home-sdk` 1.9.0 on amx, blinds and database; 1.6.0 on boiler, heating, water; 1.3.0 on presence
and shelly-cloud. Every service takes the latest with its next task (see Toolchain).

`cholewa-commons` and `cholewa-security` are intentionally hosted on the personal
`magikabdul` GitHub account (not the org): they are also used by services outside this
project. Their packages come from `maven.pkg.github.com/magikabdul/*` (pom server id
`github-prv`); the org libraries use `.../smart-home-automation-system/*`
(`github-org-smart-home`). Do not propose moving them into the org.

What a consumer has to know is in each library's `CLAUDE.md` and README. What crosses into
every consumer:

- **`smart-home-sdk`**: a field with a default is never the body of a partial update (it reads
  the same whether sent or not — `role` and `enabled` have none, the registries have separate
  enable / disable operations); lists are lists, not `uniqueItems` (a `Set` needs databind).
  **A new enum value (`RoomName`, `MemberRole`, `MemberPermission`, `DeviceKind`) is not
  additive for a reader of a whole registry** — every reader moves to the SDK that has it
  first; **renaming a constant needs a migration of the stored rows** in `database-service`.
  The `generation` of a Shelly is 1–4: ask `>= 2`. Do not build on 1.7.0 (1.8.0 replaced it
  the same day: a Bluetooth sensor has no gateway, `DeviceKind` has `temperature sensor`).
  `EatonRxEvent` and `RxEventType` of `amx-service` share names, not order: map by name.
- **`shelly-client` 2.0.0** registers three beans in every WebFlux application that bumps it
  (`ShellyRpcClient`, `ShellyGen1Client`, `ShellyMqttDecoder`; `shelly.client.enabled: false`
  keeps them out). States are text, not enums; what a device did not send is `null`; nothing
  is retried; the decoder **throws** on a body that is not what its topic carries — catch it
  inside the listener chain. `SwitchStatus` is the switch for new code
  (`ShellyPro4StatusResponse` reads power as integers). No command was ever sent to a device of
  the house through it: check the first real one on one device.
- **`cholewa-commons`**: the pooled `ConnectionFactory` from the `database.*` group (a service
  pins only `database.pool.max-size`), `NotificationPublisher` (`cholewa.notification.*`, `env`
  mandatory, no default), the pod-named RabbitMQ connection, English validation messages, the
  error contract with `code`.

### Other repositories

- `amx` — AMX/NetLinx sources for the physical control system (not Java), on the personal
  account (`magikabdul/amx-tenczynek`); the workspace directory is named `amx`. The masters
  and their addresses are in `src/systemCholewaTenczynek.apw`.
- `web-application` — the dashboard: Angular 22 + Angular Material, desktop-first, installed as
  a PWA on the household's iPhones. Current release **0.16.0** (2026-10-15, HAS-288 — the push button as a device kind; 0.15.1, HAS-231 — the
  administration of the device registry). Its plan: epics HAS-184 (foundation), HAS-185
  (heating / hot water / boiler room), HAS-186 (room view on the phone), HAS-187 (presence and
  household administration); frontend tasks carry the label `frontend`. Everything about it is
  in its own `CLAUDE.md`; what the backend side has to know:
  - **One host for the application and the API**, LAN / VPN only: its own Ingress (manifest in
    `deployment-tools/workshop/`) sends `/home` to `api-gateway-service` and everything else to
    the application — no CORS. **No route of the application may start with `/home`**; the
    host-less `smart-home-ingress` of the AMX controller is left alone. An
    `nginx-unprivileged` container on 8080, probes on `/healthz`, no Actuator, JSON access logs
    under the same `app` label; `ngsw-worker.js` and `ngsw.json` stay `no-cache`.
  - **Polling, one call after the other, the answer of a write is never used** — the page reads
    again. **Missing is never read as off**: a field the answer leaves out is shown as unknown —
    keep it out rather than send a default. Every call carries the header `ngsw-bypass` (the
    service worker never answers for the backend); an extra `GET /home/household/profiles` now
    and then is the application checking the connection, not a loop.
  - **Profiles without login**, chosen by a personal link `/u/<name>`; role, rooms and
    permissions come from the household registry. The separation is UI-only until the gateway
    validates tokens (accepted 2026-10-06). The administration of the household is the one view
    that reads the whole registry; every other view asks for the profiles.
  - **The dashboard copies backend facts — change both sides together**: the 38 / 42 °C band of
    `water-service` (`HOT_WATER_BAND`), its 3-minute interval (a reading older than 6 min is out
    of date), the enums of the SDK (`data-access/household/registry-values.ts`), the rules of the
    device registry (`features/devices/device-rules.ts`, a copy of `DeviceRules`), the floors
    of the house (`FLOORS`; a room it does not know shows under "Other"), and the error codes it
    words (the household and device codes of `CustomErrorDescription` — a renamed or new code
    needs a text in the dashboard).
  - **It writes to the house in three places only**: the heating switch (`POST
    /home/heating?turn=on|off`, after a question, never automated — browser tests run on a mock
    API; `npm start` talks to the real gateway) and the two registries of `database-service`.
    **Claude writes to the production registries only device by device, after the owner accepts
    each one** (the Eaton inventory of 2026-10-15 through the API, not the dashboard) — never
    from a test, never in bulk.
  - Endpoints it needs: `heating-service` ≥ 1.9.0, `water-service` ≥ 0.6.0, `database-service`
    ≥ 0.13.0, gateway ≥ 0.5.0; against an older one a card shows the 404 and the rest works.
  - The Definition of Done is the one of a service fitted to the frontend: `/code-review` and
    `/security-review` on the PR, verification in a browser, a live preview before the PR is
    called ready, release and deploy in every task.
- `deployment-tools` — **PRIVATE**: Kubernetes manifests (`workshop/`), local `kind` cluster
  setup, pipelines, RabbitMQ definitions and backups, the Shelly device list
  (`scripts/shelly/devices.md`). Private infrastructure details belong here, never in public
  repos.
- `organization-repository` — local clone of the org's `.github` repo: organization profile
  README and this shared Claude configuration (`claude/`).
- `claude-tooling` — Claude Code plugin marketplace with the `smart-home` plugin (org skills —
  see `claude/skills.md`).
- `tenczynek-network-setup` — **PRIVATE**: home network setup; dormant, not cloned.

## Architecture

### Messaging — RabbitMQ

- Reactive stack everywhere (WebFlux), no blocking calls in service code. Service discovery is
  Kubernetes DNS (Eureka is gone since 2026-08-13).
- **Virtual hosts, one broker user each**; exchanges, queues and bindings come from the broker
  definitions in `deployment-tools`, **no service declares them**. The secret `rabbitmq` holds
  one key per user, `<user>-password`; user names are not secrets.
  - `/temperature` (user `temperature`): `amx-service` publishes `TemperatureMessage` to the
    fanout `temperature.events`, `heating-service` consumes `temperature.prod.heating`.
  - `/notification` (user `notification`): the **headers** exchange `notification` routes by
    `category` (`alert` / `info`) and `env` (`prod` / `dev`) into
    `notification.<env>.<category>`, the routing key is ignored; the payload is **plain text**;
    a third header `level` (`error` / `warn` / `info`) colours the Discord embed and is not
    routed by. Queues have a 1-hour TTL and no dead-letter queue (accepted 2026-10-05): a
    publisher that cares repeats. Publishers: `heating-service` (silent sensors) and
    `boiler-service` (the boiler Shelly). `GET /home/notification/skippy?message=&level=`
    through a port-forward is the smoke test.
  - `/device` (users `shelly` for the devices, `device` for the services) — MQTT, below;
    `amx-service` publishes the Eaton `DeviceEvent` there over AMQP (connection `<pod>/device`).
- **A RabbitMQ connection is named after its pod** (`cholewa-commons` ≥ 1.8.0, by itself;
  outside Kubernetes `<service>-local`); a second connection adds its purpose
  (`<pod>/notification`). A new service on the broker declares nothing for it.
- Lessons for every publisher and consumer (HAS-94, HAS-109, HAS-122):
  - A second connection must **not be a bean** — any `ConnectionFactory` or `RabbitOperations`
    bean makes `RabbitAutoConfiguration` back off, and with it everything `spring.rabbitmq.*`
    sets (observation, retry). Use `NotificationConnection.create(...)`.
  - A `send` that returns proves nothing: state driven by publishing needs correlated confirms
    **and** mandatory returns (`NotificationPublisher` does both).
  - A `@RabbitListener` returning a `Mono` that errors is redelivered at once — a tight loop.
    Retry inside the chain with a backoff, only what another attempt can change, then log and
    complete. It needs `.contextCapture()` as the last operator, or everything it triggers
    loses the `traceId`.
  - A notification must neither fail nor stall what it reports on (swallow, cut off after 30 s).
  - Discord: never let discord4j list a server's channels (one undecodable channel failed the
    whole lookup) — the channel is configured by id. The look of a message is the owner's call,
    made on a real message.
  - What unit tests cannot prove (a real broker, Discord) is tested in the minute after the
    deploy. Nothing in a service can force a publish — an endpoint would be reachable through
    the gateway; prove the route by running the jar outside the cluster with `env: dev`.
- **Monitoring a device** (HAS-109): judge by whole passes and by kind of call, not single
  calls; time alone proves nothing; the device and the broker go down together, so an alert
  that never got through is announced with the return; JSON that is not the model is a failed
  call.

### Device platform (epic HAS-218)

Decisions of 2026-10-11/12: MQTT for the Shelly Gen2+ devices, action URLs and polling for
Gen1, **one registry of every device in `database-service`**, three domain services to come
(weather, blinds, light), raw Eaton frames sent through a TCP server in NetLinx, appliance
monitoring through the household notifications.

- **The broker speaks MQTT on 1883** (plugin `rabbitmq_mqtt`, HAS-219). Every MQTT client lands
  in `/device` and publishes to `amq.topic`; eight queues `device.<env>.<domain>` (`prod` /
  `dev` × `weather`, `blinds`, `light`, `heating`), each bound with `#`: **every queue gets
  every event of every device, and its service filters by the registry first**. TTL 10 min,
  no dead-letter queue; about **130 messages a minute** arrive in every queue.
  - The topic is the routing key with `/` turned into `.`: `<id>/status/switch:0` arrives as
    `<id>.status.switch:0`. Keep dots out of topic prefixes.
  - **A device that subscribes is disconnected** (`shelly` may not declare a queue), so every
    device runs with `enable_rpc: false` and `enable_control: false` — **commands stay on
    HTTP**, and `events/rpc` never arrives: read the `status` topics (the whole component about
    once a minute and at once on a change, with its `source` — `init` after a restart is not a
    change). `online: false` is the last will of a device; a battery sensor is on the broker
    only while awake. A change of the MQTT settings takes a restart of the device.
  - 39 Gen2+ devices and two battery thermometers are connected (HAS-220); the wall display, the
    Bluetooth sensors behind the gateway and the Gen1 devices are not. The topics per model are
    in `deployment-tools/scripts/shelly/devices.md`. The plug PRINTER stays connected as a live
    event source.
  - The owner's rule (2026-10-11): **a backup of the broker before any work on it and a second
    one after**, only the last pair kept. Definitions are imported with
    `rabbitmqctl import_definitions` (README of `deployment-tools/k8s/rabbitmq`).
- **The device registry** (`database-service` ≥ 0.13.0, `SmartDevice` of `smart-home-sdk`
  1.8.0): one table for every device, the 13 Eaton room sensors (gateway `blinds`, points 45–57)
  included. `PUT` replaces a device whole (no `PATCH`); the id, the kind and the time of
  registration survive it; `INVALID_DEVICE` (400) and `DEVICE_CONFLICT` (409) carry the reason in
  `details`; a Shelly Gen2+ must have its `deviceId`. **A write to the registry is a write to the
  Eaton configuration**: moving or removing an Eaton device changes what `amx-service` reads for
  the next datagram of its point — removing a room sensor ends that room's temperature
  readings. A switched-off device is still found by its point; `enabled` is read by no service
  yet. Calls for one device go one after the other.
- **Eaton through `amx-service`**: **the socket to the frame server of the Television master
  is the only way between the AMX and the backend** (HAS-230 / HAS-286, since 2026-10-14):
  every frame of both gateways arrives as a line `<blinds|lights>;<hex>`, commands go back the
  same way, the HTTP `POST /home/amx` path is retired. The line protocol is pinned in
  `amx/CLAUDE.md`; a change there is a change in `amx-service`. A frame of a registered
  blinds, light or dimmer is published as a `DeviceEvent` (`amx-service` ≥ 2.1.0, HAS-229) to
  `amq.topic` in `/device`, routing key `eaton.<gateway>.<point>` — every `device.*` queue gets
  it, and so are the push buttons and PIR sensors (HAS-288, `amx-service` 2.2.0 / `database-service` 0.15.0 / SDK 1.9.0). The Eaton devices of the house, what each gateway hears and what it does not, are listed in `deployment-tools/scripts/eaton/devices.md`. The writes never send a
  frame twice: a 504 or a lost connection means "may have been carried out"; `OK` of the frame
  server says the gateway got the bytes, the gateway's own `C3` status says whether the
  telegram went out (an error status is a WARN in `amx-service`, the caller already has its
  202). The health of `amx-service` shows the socket as `frameServer`, outside the probes: a
  master that is off does not take the pod out of the Service.
- **The calendar of the house** (`database-service` 0.14.0): read `type`, never `reason`; only
  the household's days off are stored, the Polish statutory holidays are computed (a holiday a
  later law adds needs a release); a holiday or a weekend cannot be made a workday.

### External traffic — the gateway

- Ingress `/home` → `api-gateway-service` → the services, by static routes in
  `internal.service.*`. Verified in the gateway sources (HAS-171): `PathRoutePredicateFactory`
  **prepends** `spring.webflux.base-path` (predicates are written without `/home`, nothing is
  stripped), and `RouteToRequestUrlFilter` merges only scheme, host and port — a target mounted
  elsewhere needs `rewritePath`.
- **Nothing behind the gateway is authenticated**, writes included (a `DELETE` of an Eaton room
  sensor is one call from the LAN). Accepted: access is LAN / VPN only.
- `notification-service` is deliberately not routed. `presence-service` is routed as an
  **allowlist** of its four report reads, `GET` only — `PathPattern` matches the raw path, so a
  `/**` tail would publish `residents/../clients`; **every new endpoint of `presence-service`
  needs a gateway release**. Exposing who is at home was accepted (2026-10-05) — do not
  re-raise, but a new presence endpoint gets its own look at what it exposes.
- `database-service` is routed by path with **open tails, on purpose** (every method; what that
  service adds below a routed path is published without a gateway release) — do not propose an
  allowlist; `/device` is listed by branch (`configuration`, `registry`), so a third branch
  needs a gateway change. A pattern ending in `/**` matches the bare path. The full `GET
  /home/household` stays routed (owner, 2026-10-08) — do not re-raise. `/amx/**` routes the
  writes of `amx-service` — the only thing it answers over HTTP since 2.0.0 (the README of
  `api-gateway-service` still lists `POST /home/amx`; to correct with its next task).
- **A broken connection to a service is a 502 with a body, and a `GET` without a body is
  repeated once** when it broke within 1 s (gateway 0.4.0, HAS-212; logged at WARN). The pool
  closes a connection idle for 2 min or older than 30 min (conntrack forgets an idle connection
  after 24 h, which had produced bare 500s). A `POST` is never repeated. The same stale
  connection between services cost one temperature reading after a `database-service` restart —
  accepted (2026-10-11), do not re-raise.
- The gateway pins `spring-cloud-starter-gateway-server-webflux` (5.0.3) by hand: no release
  train targets Boot 4.1. **An accepted risk — re-test the gateway on every bump** of Boot or the
  starter (recipe in its `CLAUDE.md`: the jar with `home,local` and a stub, no cluster needed).

### Database

- One managed PostgreSQL with **22 usable connections for the whole cluster** (25 minus 3
  reserved), not for this project alone. Split: **heating 2 / database 4 / water 2 /
  presence 2 / blinds 2 — 12 allotted, 10 free** for Flyway, tools and services to come. It is sized for
  RollingUpdate (the old and the new pod each hold a pool, Flyway adds one): deploy services with
  a database one at a time; raising a pool means redoing the sum; each service pins its size
  with a test.
- **Every database belongs to `doadmin`, not to the user of the services** — PostgreSQL 15+
  gives `CREATE` on `public` to the owner only, so a new database needs `GRANT USAGE, CREATE ON
  SCHEMA public TO <user>` (as `doadmin`, in that database) before the first start, or Flyway
  fails with `permission denied for schema public` (HAS-243).
- The pool comes from `cholewa-commons` (`database.*`); it validates on acquire (bound 2 s, keep
  it well below `max-acquire-time`), caps the life at 30 min and recovers gradually. Drop
  `@EnableR2dbcRepositories` when adopting it (a `@WebFluxTest` slice would build repositories).
- Before a prefetch, a timeout or a pool size is tied to another number, check what an
  in-flight message actually holds and what a timeout cancels (HAS-169, HAS-128): each device
  call gets its own `onErrorResume`, or one slow relay cancels the rest of the pass — the
  furnace included.
- **Status tables insert on a change only**, otherwise they move `last_checked_at`.
- **Migrations**: rehearse with the **released image** against a throwaway PostgreSQL in Docker
  (it must speak SSL — `sslMode REQUIRE`), then the new build on the same database — never a
  local run, which talks to production. Replacing a table under a rolling deploy: copy in one
  release, drop in the next. A deployment far behind can cross a rewritten migration — give it a
  new database, never `flyway repair`.
- Measuring `pg_stat_activity` through the DataGrip MCP costs a connection per query — take one
  sample at the peak (data source `DigitalOcean` / `home-automation-data`).

### Errors between services

- `ErrorMessage` of `cholewa-commons` has an optional `code` — the **name** of an `ErrorId`
  constant; **the name is wire contract once a caller branches on it**, so the owning service
  pins the names with a test. Callers today: `amx-service` (`NOT_FOUND_DEVICE_CONFIGURATION`,
  `NOT_FOUND_DEVICE`) and the dashboard (household and device codes).
- Only named causes travel past the first hop, and never their `details` (the raw exception
  text).
- A client of another service: a 502 answers with the downstream status alone and what the
  downstream said goes to the log; no body, or JSON that is not the model (`{}` decodes into
  nulls), is a failed call, not an empty result; the test asserts the **log level**, which is
  what the alerts see. `amx-service` ≥ 1.3.0 must never run next to `database-service` below
  0.8.0.

## Toolchain and versions

- **Target: Java 21, Spring Boot 4.1.x** (`spring-boot-starter-parent`), Maven, groupId
  `cloud.cholewa`. The migration from Java 17 / Boot 4.0.1 is **finished** for every repository
  (2026-08-13); its chronicle is in `history.md`. Every service is on Boot **4.1.1**.
- **Spring Boot and the own libraries follow one rule**: when a newer release exists, the
  repository being worked on moves to it in that task (a no-op bump included); the others follow
  with their next task. A mixed fleet after a release is the expected state, not drift to
  report. Libraries with a Boot parent follow it too; a library built on a newer Boot is fine
  for a consumer on an older one.
- What the migration taught, still true for every new service or bump:
  - Boot 4 dropped `layertools`: the image starts with `-jar application.jar`, the `Dockerfile`
    extracts with `-Djarmode=tools ... extract --layers`.
  - A service building a `WebClient` needs `spring-boot-starter-webclient`; logbook 4.x needs
    `spring-boot-http-client`. Build a `WebClient` from the **injected** builder, or it is
    untraced. Never declare an own `WebClient.Builder` or `RabbitTemplate` bean.
  - Surefire `includes` match `**/*Test.java` — a `...Tests` class silently stops running.
  - Mockito refuses to mock sealed types (`RETURNS_SMART_NULLS` on a `Clock` fails).
  - A `@RabbitListener` returning `Mono` with prefetch throttling sets
    `acknowledge-mode: manual`.
  - No Spring Cloud release train targets Boot 4.1: drop the BOM (Eureka is gone anyway).
  - logbook 4.2.0 brings apiguardian 1.1.2 itself: no exclusion and no pin needed.
  - A repo scaffolded as a copy: check the image name, the Discord titles and the README.
- `heating-service` is the reference for the shape of a service; `water-service` the scaffold of
  a new one (`new-service` skill); `smart-home-sdk` the reference library (`new-library`).

## Conventions

- **Ports**: in the cluster every service listens on **6200** and Actuator on **8200**
  (`management.server.port` in `home`); probes on `/actuator/health/{readiness,liveness}`, with
  `management.endpoint.health.probes.enabled: true` in the shared document; `EXPOSE 6200 8200`.
  Locally each service keeps **600x** / **800x** (the `local` profile; services run locally
  with `home,local`).
- **Observability** (epic HAS-155): every service exposes `health,info,prometheus` on 8200 and
  carries the `prometheus.io/scrape|port|path` annotations. The identity label is **`app`** in
  Prometheus and Loki; dashboards are ConfigMaps in `deployment-tools`. Logs are JSON
  (`logging.structured.format.console: logstash` in the shared document, `""` in `local`
  **and** `test`; surefire activates `test` for every class, and context tests carry
  `@ActiveProfiles("test")`). JSON logs make anything echoed from an upstream error stored text
  — map provider failures to a fixed message (an OpenAI error quoted the API key back).
- **Tracing**: Micrometer Tracing with Brave, **no exporter** — the trace lives in the logs
  (`traceId` / `spanId` as top-level JSON fields; `{namespace="smart-home"} | json | traceId =
  "…"`). It needs `spring.reactor.context-propagation: auto`, both
  `spring.rabbitmq.{template,listener.simple}.observation-enabled`, and sampling `1.0`. A
  `@Scheduled` pass shares one `traceId` by itself. Logbook's own lines never carry it.
- **Logbook stays at `trace` with full bodies** (decided 2026-08) — do not propose trimming. If it
  ever must be trimmed, use `logbook.strategy` / `write.max-body-size` / `exclude`, never the
  level (`info` disables it). Its JSON is escaped inside `message`: `| json | line_format
  "{{.message}}" | json`.
- **Error messages are English, always** — in responses and logs, on every machine.
  `cholewa-commons` ≥ 1.6.0 pins Bean Validation to `Locale.ROOT`; a consumer keeps a context
  test on a Polish JVM. A locale-dependent text is a defect to fix, not to document — except
  the validation of `@ConfigurationProperties` at startup (accepted 2026-10-05).
- **A constraint on a `@RequestParam` / `@PathVariable` needs no `@Validated`** — that annotation
  switches WebFlux's own validation off and validates `@Valid` bodies twice.
- **A `Duration` property without a unit binds as milliseconds**: a duration that decides what is
  deleted or how long something waits carries `@DurationUnit` and `@DurationMin`, pinned by a
  test. Timeouts are validated records with a lower and an upper bound.
- **A reactive `@Scheduled` method is called once**: Spring subscribes again to the same `Mono`
  for every run, so "now" or anything read while building it is frozen at the start of the pod.
  Put it inside the chain (`Mono.defer`); the test subscribes twice with the clock moved on.
- **A `@SpringBootTest` context schedules what the application schedules**: `@EnableScheduling`
  under `@Profile("!test")`, devices pointed at `localhost:1` in `test`. A local run of
  `boiler-service` drives the real relays.
- `LocalDateTime.now(ZoneId.systemDefault())` with the zone explicit (since 2026-07-30; older
  places are fixed in passing, not reported).
- **Mandatory connection settings get no default** in a document a pod runs with; and a
  placeholder is not a value — `${rabbitmq-password}` without the variable binds as its own
  text (`BrokerPasswordCheck` in heating and boiler refuses the start).
- **Calling a device or gateway outside the cluster** (HAS-149): pin a self-signed certificate by
  fingerprint (`setEndpointIdentificationAlgorithm("")` to drop hostname verification — `null`
  is ignored); map every failure, the body included (`bodyDelay`, a closed socket, `{}`); keep
  the wire and the domain model apart. Tests use `mockwebserver3`, never the legacy
  `mockwebserver` (JUnit 4 — still in heating and water); a `MockWebServer` per test, no fixed
  port, no shared connection pool.
- **Repository tests**: H2 in a `@DataR2dbcTest` slice for portable statements; Testcontainers
  PostgreSQL for PostgreSQL-only SQL (heating and water fail without a Docker,
  `database-service` skips without one — but not where `CI=true`).
- **Code moves into `cholewa-commons` only when more than three services use it** (owner,
  2026-10-11). Up to three copies stay — no review finding, no task; note the copy in each
  service's `CLAUDE.md` (today: `BrokerPasswordCheck`, two copies).
- Private **LAN IPs** already in service configs are tolerated (2026-07) — do not flag them.
  Secrets, tokens and credentials remain strictly forbidden in public repos.
- **CI/CD** — GitHub Actions in every repo: `CI.yml` (build + tests), `sonar.yml`, and
  `release.yml` (services: Docker image `magikabdul/<repo>` on Docker Hub) or `package.yml`
  (libraries: GitHub Packages), both on a GitHub release; poms keep a dev version. **The Discord
  message of `CI.yml` carries no commit** (owner, 2026-10-12): one step with `if: always()`,
  built with `jq` and `curl` — copy it from `smart-home-sdk/.github/workflows/CI.yml`. No task of
  its own: convert a repository in the PR of its next task. Converted: `smart-home-sdk`,
  `database-service`, `api-gateway-service`, `shelly-client`, `amx-service`, `blinds-service`
  (new); 10 repositories still have the old form.

## Working rules for Claude

- **Spring Boot services and libraries**: the user writes the code themselves. Do NOT write
  or modify code there unless explicitly asked. Default contributions: analysis, code
  review, security review, answering questions.
- **`web-application`**: full autonomy — Claude designs and implements the frontend.
- **`amx`**: NetLinx language; analysis and suggestions, ask before modifying. The owner
  writes the NetLinx code and transfers it to the masters.
- Never commit or push unless explicitly asked.
- **All changes to Spring services, libraries, `web-application` and the NetLinx code of
  `amx` go through pull requests** — no direct commits to `main`. Branch naming:
  **`feature/HAS-<n>`**, where `<n>` is the Jira task number (HAS project). When no Jira
  task covers the change, create one first (`jira-backlog`) or confirm with the user how to
  proceed.
  - **`amx` (owner, 2026-10-14): `/code-review` alone** before a PR is called ready
    (`service-review` is written for Spring). Documentation-only changes (`README.md`,
    `CLAUDE.md`) may go straight to `main`.
  - **No merge without both reviews.** Before a PR of a service or library is called ready
    for merge, Claude runs **`service-review` and `/code-review`** on its diff, shows the
    results and records the outcome on the PR. Until both are done: no merge, so no release
    and no deploy — Claude does not hand over a `gh release create` command for an
    unreviewed change. This holds for small follow-up PRs too.
  - **Exceptions — commit straight to `main`, no branch or PR:** `organization-repository`
    (this `.github` repo), `deployment-tools` and `claude-tooling`. They do not need a Jira
    task of their own; reference the task in the commit message when one exists.
- All repos except `deployment-tools` are public: never put secrets, tokens, IP addresses,
  or private infrastructure details into files of public repos (the tolerated LAN IPs aside,
  see Conventions).
