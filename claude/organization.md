# Smart Home Automation System — organization context

Solo-developer project: a set of repositories under the GitHub organization
[smart-home-automation-system](https://github.com/smart-home-automation-system) that together
control a real smart home — an AMX/NetLinx control system with Eaton wireless devices, and
Shelly Wi-Fi devices. The backend runs on a Kubernetes cluster. All repositories are public
except `deployment-tools`.

## What belongs in this file

This file is loaded into **every** session, so it holds only what crosses repositories: the
map of the repositories, the contracts between them, and the rules every repository follows.
**What one service, library or the dashboard does in detail belongs to its file in
`claude/services/`, its own `CLAUDE.md` and README**, not here — a task changes the version of its row below and writes
the rest there. Claude Code refuses a file above 150k characters; keep this one around 60k.
The full history of the decisions summarised here is in `claude/history.md` (an archive of
2026-10-14, not imported) — read it when the history of a decision matters.

## Repository map

**Each service, each library and the dashboard has a file in `claude/services/<name>.md`** (not imported - read on
demand): what it does in detail, its release history, and at its top what it depends on. **Before working on a
repository read its file, and the files of the services it calls or is called by** (the table below, repeated at the
top of each file) whenever the change crosses to them - an endpoint, a payload, an event, a command source, an error
code. After a release: the history goes into that file, the row here changes only its version.

| Service | Calls over HTTP | Called by (besides the gateway and the dashboard) |
|---|---|---|
| `api-gateway-service` | ai, aircon, amx, appliance, blinds, boiler, database, energy, gate, heating, light, media, presence, safety, water, weather | - |
| `amx-service` | database, weather, gate | blinds, light, gate |
| `heating-service` | database | boiler, aircon |
| `notification-service` | database, presence | - |
| `ai-service` | - | - |
| `database-service` | - | amx, heating, notification, water, presence, weather, blinds, light, appliance, energy, aircon, gate, safety, media |
| `water-service` | database, light, presence | boiler |
| `boiler-service` | heating, water | - |
| `presence-service` | database | notification, water, light, appliance, aircon, gate |
| `weather-service` | database | amx, blinds, energy, gate |
| `blinds-service` | database, amx, weather | safety |
| `light-service` | database, amx, presence | water, safety |
| `appliance-service` | database, presence | - |
| `energy-service` | database, weather | aircon |
| `aircon-service` | database, heating, presence, energy | safety |
| `gate-service` | database, weather, presence, amx | amx |
| `safety-service` | database, light, blinds, aircon | - |
| `media-service` | database | - |

### Spring Boot microservices (all reactive — WebFlux)

| Repository | Local port | Purpose | Release |
|---|---|---|---|
| `api-gateway-service` | 6200 | Spring Cloud Gateway - the **only** entry point into the cluster from outside; static routes to the services over k8s DNS (see External traffic). A new routed path of a service is a gateway release. | **0.14.0** (2026-11-27, HAS-516) |
| `amx-service` | 6001 | The bridge to the AMX control system: one permanent TCP socket to the frame server of the Television master (every Eaton frame of both gateways in, Eaton commands out) and a second one to the panel server of the Office master (the door panels of the entrance and the hall: doorbell, outside temperature, gate button). Publishes the room temperatures and the Eaton `DeviceEvent`; its HTTP side is only writes (`/home/amx/**`). The line protocols are pinned in `amx/CLAUDE.md`. | **2.8.0** (2026-11-23, HAS-487) |
| `heating-service` | 6002 | Heating control: rooms, heaters and their schedules (read and written through the API), the house switch, the temperature sensors (Eaton, Shelly, BLU), open windows holding a room (`window` in `GET /rooms`), the stored temperature history. `GET /home/heating/rooms` is read by aircon-service and the dashboard; `GET /status/active` by boiler-service. | **1.23.2** (2026-11-13, HAS-433) |
| `notification-service` | 6003 | Consumes the `alert`, `info` and `household` queues and delivers them: the technical Discord channel, and for the household Polish wording (`HouseholdMessages`) over Discord, Web Push and SMS (SMSAPI); the household requests texted at 08:00 with evening reminders. Deliberately not routed. A new `HouseholdEvent` must be readable here before its publisher sends it. | **0.15.1** (2026-11-25, HAS-498) |
| `ai-service` | 6004 | AI integration (Spring AI 2.0 `ChatClient`, OpenAI). | **0.2.1** |
| `database-service` | 6005 | The persistence facade: the household registry (members, roles, rooms, permissions, profiles, push subscriptions, household requests), the **device registry** of every device of the house (the Eaton configuration of amx-service is served from it) and the calendar of the house. A new `DeviceKind` or vendor is readable only from the release that added it - no rollback below it once a device of that kind is stored. | **0.29.0** (2026-11-26, HAS-510) |
| `water-service` | 6006 | Hot water (the tank, the flag boiler-service polls, the circulation pump and its automation), the water meter of the house (the Neo valve: readings, consumption, alarms, the valve command, the bills) and the water softener (the iQua cloud: state, history, alerts, regeneration, live flow). State in memory: `Recreate`, never scaled. | **0.19.0** (2026-11-09, HAS-401) |
| `boiler-service` | 6007 | Drives the furnace and both pumps as relays of one Shelly Pro 4 from what heating-service and water-service ask for; alerts when that Shelly stops answering. A local run drives the real relays. | **1.4.0** (2026-10-23, HAS-306) |
| `shelly-cloud-service` | 6008 | Shelly cloud integration - a **skeleton** (Actuator only, no endpoints). | **0.1.1** |
| `presence-service` | 6009 | Household presence: UniFi clients matched against the household registry every minute, status changes stored, four routed reports (a GET allowlist - every new endpoint needs a gateway release), an alert when the detection does not run. `GET /home/presence/residents/presence` is read by water, light, appliance, aircon, gate and notification. `Recreate`, never scaled. | **0.8.0** (2026-11-26, HAS-511) |
| `weather-service` | 6010 | The weather station (Shelly WS90 through a BTHome gateway) and the air quality sensor (BleBox): the current state, the history, the alerts of silence and the smog told to the household. `GET /home/weather/current` is read by blinds, energy, gate and amx. Routed as a GET allowlist - every new endpoint needs a gateway release. `Recreate`, never scaled. | **0.8.0** (2026-11-13, HAS-437) |
| `blinds-service` | 6011 | Roller shutters: Eaton blinds through amx-service, Shelly Gen1 and Gen2 blinds, the real state, weather- and calendar-aware schedules, window sensors per blind, the pause of the schedules of a blind, unconfirmed commands and unreachable blinds alerted. `GET /home/blinds/events/gen1` is a `GET` with a side effect by design. Takes the command source `safety`. `Recreate`, never scaled. | **0.12.0** (2026-11-22, HAS-466) |
| `light-service` | 6012 | Lights: Eaton lights through amx-service, Shelly lights, the real state, the occupancy of a room (presence and motion sensors), room rules (auto-off, motion-on, manual hold), the empty house with its presence simulation, the availability monitor. `GET /home/light/rooms/{room}` is read by water-service; takes the command source `safety`. `Recreate`, never scaled. | **0.12.0** (2026-11-21, HAS-465) |
| `appliance-service` | 6013 | Appliance monitoring: the cycles of the washing machine, the dryer and the dishwasher from the power draw of their Shelly plugs, the household told when one finished and reminded until it is acknowledged (in the application or by the NFC tag of the appliance), the chores per member. `Recreate`, never scaled. | **0.10.0** (2026-11-26, HAS-512) |
| `energy-service` | 6014 | The energy of the house: the grid meter (Shelly Pro 3EM), the SOLAX and SOFAR inverters, the SOLAX battery, the SolaX and Solarman clouds, Tauron (planned outages, the eLicznik) and the Open-Meteo forecast - readings, history, days and net-metering, the outages of the grid, alarms, charging the battery from the grid (on demand and before a planned outage), the battery reserve and the settings of the inverter read from its dongle. `GET /home/energy/status` is read by aircon-service. `Recreate`, never scaled. | **0.24.0** (2026-11-26, HAS-495) |
| `aircon-service` | 6015 | The air conditioners: five Gree indoor units over their local protocol (no cloud) - state, commands with the 22 C cooling minimum, a rule per unit, open windows (from heating-service), the empty house and a lost grid, the power draw of their plugs, the filter hours. Takes the command source `safety`. `Recreate`, never scaled. | **0.12.0** (2026-11-22, HAS-467) |
| `gate-service` | 6016 | The driveway gate and the intercom (the events of the Hikvision door station from the SDK bridge of `deployment-tools`), the two garage gates with their state, alarms and pulse, the events timeline, the household told of a ring and an opening; every ring wakes the door panels (entrance and hall) through amx-service. `POST /home/gate/open` is called by the dashboard and by amx-service (`source=panel`). `Recreate`, never scaled. | **0.13.0** (2026-11-26, HAS-513) |
| `safety-service` | 6017 | The fire detectors (X-Sense, from the MQTT of the SBS50 base station): state, the fire alarm told to the whole household, the technical monitor, mute and self test, and the reactions to an alarm (lights on, blinds up, air conditioners off - each `source=safety`, behind switches that are off by default). `Recreate`, never scaled. | **0.5.0** (2026-11-22, HAS-468) |
| `media-service` | 6018 | The audio and video equipment of the house - first the unlock of the amplifier that hangs after every loss of the grid (epic HAS-508; the route HAS-516, the button HAS-517). `POST /home/media/amplifier/unlock?source=dashboard&member=` sends the amplifier one file of its firmware form, once, one at a time, for a member with `amplifier_unlock` (the profiles of database-service); 202, the seven codes worded by the dashboard. No database, no broker, stateless (`RollingUpdate`). Its state cannot be read: never a status or a detection. | **0.2.0** (2026-11-27, HAS-515) |

Do not confuse `api-gateway-service` (HTTP edge) with `amx-service` (AMX hardware bridge).

### Shared libraries (Maven, `cloud.cholewa` group)

| Library | Purpose | Current consumers | Latest |
|---|---|---|---|
| `cholewa-commons` | Common utilities: the error contract, the pooled R2DBC factory, English validation messages, the RabbitMQ connection name, `NotificationPublisher`, the required properties, `DomainExceptionProcessor`, Logbook in the reactive chain, the scheduler pool and `ScheduledPass`. | ai, aircon, amx, api-gateway, appliance, blinds, boiler, database, energy, gate, heating, light, media, notification, presence, safety, shelly-cloud, water, weather | **2.0.0** (HAS-494) |
| `cholewa-security` | Security / auth. | none yet — kept for possible future auth in `api-gateway-service` | **1.0.0** |
| `smart-home-sdk` | Shared domain / API models (household, device registry, calendar, device events, household notifications). | aircon, amx, appliance, blinds, boiler, database, energy, gate, heating, light, media, notification, presence, safety, shelly-cloud, water, weather | **1.26.0** (HAS-509) |
| `shelly-client` | Models of what a Shelly answers and publishes, reactive HTTP clients (Gen2+ RPC, Gen1) and the MQTT decoder. | aircon, appliance, blinds, energy, gate, heating, light, water, weather (2.7.0); boiler (2.1.0 - its clients switched off); shelly-cloud (still on 1.0.0) | **2.7.0** (HAS-389) |

Versions in the services (2026-11-07): `cholewa-commons` 2.0.0 on api-gateway, appliance, database, energy, gate, media, notification and presence; 1.14.0 on aircon, amx, blinds, heating, light, safety and weather; 1.13.0 on water; 1.11.0 on boiler;
1.7.0 on ai and shelly-cloud.
`smart-home-sdk` 1.26.0 on appliance, database, gate, media and presence; 1.25.0 on amx, energy and notification; 1.24.0 on aircon, blinds, light and safety; 1.21.0 on weather and heating; 1.18.0 on water; 1.12.0 on boiler; 1.3.0 on
shelly-cloud. Every service takes the latest with its next task (see Toolchain).

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
  **`hall up` (1.10.0, HAS-289)**: `RoomName.HALL_UP` was `hall_up` until 1.9.0 - a renamed value, so
  the same rule as a new one: no member or device is set to hall up until every reader of the
  registries (amx, blinds, presence, the dashboard) runs 1.10.0; 1.10.0 still reads `hall_up`.
  **`openingSensors` (1.11.0, HAS-290)**: the opening sensors on the window of one blinds, by
  registry id - per blind, never per room. A whole-device `PUT` without the list removes the link:
  every writer of whole blinds sends it back (the dashboard keeps a field it does not know since
  0.15.1; Bruno sends what it read).
  **A channel may be a zone (1.12.0, HAS-260)**: 0-3 is an output of any kind, 200-299 the zone of a
  `presence sensor` (`presencezone:200`, the main zone of the three Presence Gen4, registry 91-93) -
  the registry refuses anything else; a reader takes the channel as it comes and never assumes it is below 4.
  **Appliances (1.13.0, HAS-271)**: `DeviceKind.appliance` with its `ApplianceSettings` (eight
  required settings, quiet times as `HH:mm` text). The services read the registry by `?kind=`, so
  only the readers of every kind - the dashboard and `database-service` (two exhaustive switches) -
  move to 1.13.0 before a plug is registered. `HouseholdNotification` is the JSON payload of the
  `household` category, words composed by notification-service. `PushSubscription` is a model of its
  own, **never a field of `HouseholdMember`**: served on endpoints of their own, the read of
  notification-service outside the routed prefixes (HAS-272); its endpoint takes any https address,
  so the sender allowlists the push hosts (notification-service 0.6.0, `household.push.allowed-hosts`), and it is logged by its endpoint only.
  **Inverters (1.15.0, HAS-326)**: `DeviceKind.inverter` reached by `InverterBinding` alone (the
  SOLAX and the SOFAR, registry 134 and 135, read by energy-service). Every service reads the
  registry by `?kind=` and the dashboard shows an unknown kind as it comes, so only
  `database-service` had to move first.
  **Air conditioners (1.18.0, HAS-377, epic HAS-376)**: `DeviceKind.air conditioner` reached by `GreeBinding`
  alone (the IPv4 address and the MAC as the unit gives it - 12 hex digits, lower case, no separators; the
  key of a unit is never stored), with a **new vendor `gree`** - the first new `SmartVendor` since the
  registry began. aircon-service reads by `?kind=`, so no other service moves for it; `database-service`
  (HAS-378: the rule of `gree` in `DeviceRules`) and the dashboard (its `VENDORS` and devices form) move
  before the first unit is stored.
  **Air quality sensors (1.20.0, HAS-424, epic HAS-423)**: `DeviceKind.air quality sensor` reached by
  `BleboxBinding` alone (the IPv4 address and the `deviceId` of `GET /info` - 12 hex digits, lower case),
  with the **second new vendor `blebox`**. weather-service reads by `?kind=`, so no other service moves for
  it; `database-service` (HAS-425) and the dashboard (HAS-426) move before the sensor is stored.
  **Garage gates (1.23.0, HAS-470, epic HAS-442)**: a `gate` with `openingSensors` is a garage gate (its state
  is known), a `gate` without one the driveway gate - the same field as for blinds, so a whole-device `PUT`
  without the list removes the link. Four household events of a gate left open, `reminder` 0-10 as before: the
  publisher stops repeating at 10 (owner, 2026-11-18).
  **Fire detectors (1.24.0, HAS-456, epic HAS-455)**: `smoke detector`, `co detector` and `heat detector` came at
  once, so a reader of the whole registry moves only once, with the fourth new vendor `xsense` reached by
  `XsenseBinding` alone - the base station of a detector by its serial (`SBS50` and eight upper-case hex digits,
  its client id on the broker) and the id the base gives it; the base itself is not a registry device.
  `database-service` and the dashboard move before the first detector is stored; safety-service reads by `?kind=`.
  The fire alarm carries the `room` of the detector, so notification-service words it without a registry read.
  **The amplifier unlock (1.26.0, HAS-509, epic HAS-508)**: `MemberPermission.amplifier_unlock` - a new permission,
  so the same rule as a new enum value: database-service (HAS-510), presence-service (HAS-511), appliance-service
  (HAS-512), gate-service (HAS-513) and the dashboard (HAS-517) read it before the owner grants it to anybody;
  notification-service reads the registry with a record of its own and does not move for it.
- **`shelly-client` 2.0.0** registers three beans in every WebFlux application that bumps it
  (`ShellyRpcClient`, `ShellyGen1Client`, `ShellyMqttDecoder`; `shelly.client.enabled: false`
  keeps them out). States are text, not enums; what a device did not send is `null`; nothing
  is retried; the decoder **throws** on a body that is not what its topic carries — catch it
  inside the listener chain. `SwitchStatus` is the switch for new code
  (`ShellyPro4StatusResponse` reads power as integers). No command was ever sent to a device of
  the house through it: check the first real one on one device. **The BTHome components are not in
  `Shelly.GetStatus`**: `dynamicComponents` (2.1.0) reads them from `Shelly.GetComponents`, page by
  page - checked on the gateway of the weather station.
- **`cholewa-commons`**: the pooled `ConnectionFactory` from the `database.*` group (a service
  pins only `database.pool.max-size`), `NotificationPublisher` (`cholewa.notification.*`, `env`
  mandatory, no default), the pod-named RabbitMQ connection, English validation messages, the
  error contract with `code`. **1.10.0 (HAS-298) changes the logging of every consumer by default**:
  `logbook.reactive.server-mode` is defaulted to `web-filter` and a `LogbookExchangeFilterFunction` is
  put on the injected `WebClient.Builder`, so the Logbook lines carry `traceId` / `spanId` - a service
  that bumps **removes its own `LogbookClientHandler`** (all six consumers so far did -
  heating, blinds, light, boiler, weather, presence) or it logs
  every outgoing call twice; a `WebClient.create()` or a bare `HttpClient` is not logged; a filter the
  service adds afterwards runs after Logbook's; `cholewa.logbook.reactive-filters: false` keeps the
  handlers. The gateway proxies through its own `HttpClient`: re-test it on the bump. **1.10.1 keeps the
  actuator out of the server side of the log** (`logbook.server.predicate.exclude` defaulted to
  `/actuator/**`; a list of the service's own replaces it whole, so it names the actuator itself).
  **1.11.0 (HAS-300) gives the scheduler a pool** (`spring.task.scheduling.pool.size` defaulted to 10):
  Spring blocks a scheduler thread until a reactive `@Scheduled` pass completes, and with Boot's one
  thread a hung pass stopped every task of blinds-service on 2026-10-22. A service that bumps wraps every
  reactive `@Scheduled` method in `ScheduledPass.bounded(task, limit, pass)` (limit below its fixed
  delay; commands that must not be cut off stay outside) and checks that its tasks, now concurrent, share
  no unsafe state and fit its R2DBC pool together (HAS-301…307).
  **2.0.0 (HAS-494) follows Boot 4.2.0**, which moved the classic RabbitMQ support from `spring-boot-amqp` (now the
  AMQP 1.0 client) to `spring-boot-rabbitmq` and its classes to `org.springframework.boot.rabbitmq.autoconfigure`:
  **a consumer with a broker on Boot 4.1 gets no `NotificationPublisher`**, so it takes 2.0.0 in one change with
  Boot 4.2.0, `spring-boot-starter-rabbitmq` in place of `spring-boot-starter-amqp`, the new imports and - in its
  copy of `NotificationRabbitConfig` and any second connection - the host and port from the `RabbitConnectionDetails`
  bean (`getFirstAddress()`): `RabbitProperties.determineHost` / `determinePort` are deprecated for removal (4.4.0)
  and Sonar flags them. **A `spring.autoconfigure.exclude` that names `org.springframework.boot.amqp.autoconfigure.RabbitAutoConfiguration`** (the `test` document of a service) excludes nothing after the move and the build stays green while every test context tries the broker - rename it to `org.springframework.boot.rabbitmq.autoconfigure.RabbitAutoConfiguration` (notification-service, HAS-498). A consumer without a broker (database, api-gateway, ai, shelly-cloud) is not affected.

### Other repositories

- `amx` — AMX/NetLinx sources for the physical control system (not Java), on the personal
  account (`magikabdul/amx-tenczynek`); the workspace directory is named `amx`. The masters
  and their addresses are in `src/systemCholewaTenczynek.apw`.
- `web-application` — the dashboard: Angular 22 + Angular Material, desktop-first, installed as a PWA on the household's
  iPhones. Current release **0.62.1** (2026-11-25, HAS-499). Frontend tasks carry the label `frontend`. Its release history,
  the views, **every place it writes to the house** and **the minimum version of each service a view needs** are in
  `claude/services/web-application.md` - read it before changing an endpoint the dashboard uses. What every backend
  task has to know:
  - **One host for the application and the API**, LAN / VPN only: its Ingress sends `/home` to `api-gateway-service` and
    everything else to the application - no CORS. **No route of the application may start with `/home`**.
  - **Polling, one call after the other; the answer of a write is never used** - the page reads again. **Missing is
    never read as off**: a field an answer leaves out is shown as unknown - leave it out rather than send a default.
  - **Profiles without login** (`/u/<name>`); role, rooms and permissions come from the household registry. The
    separation is UI-only until the gateway validates tokens (accepted 2026-10-06).
  - **The dashboard copies backend facts - change both sides together**: the enums of the SDK, the rules of the device
    registry (`DeviceRules`), the schedule rules of blinds and heating (`ScheduleRules`), `BillRules` and the bands and
    intervals of water-service, `CommandRules` / `RuleRules` of aircon-service, the rules of the battery reserve and the
    household requests, the room rules of light-service, and every error code it words - a renamed or new code needs a
    text in the dashboard. Against a service older than a view needs, its card shows the 404 and the rest works.
  - **Claude writes to the production registries only device by device, after the owner accepts each one** - never from
    a test, never in bulk. Browser tests run on a mock API; `npm start` talks to the real gateway.
  - The Definition of Done is the one of a service fitted to the frontend: `/code-review` and `/security-review`,
    verification in a browser, a live preview, release and deploy in every task (the order: `claude/working-rules.md`).
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
    routed by. **A fourth header `sms` = `true`** (the `...Sms` methods of `cholewa-commons` 1.13.0,
    HAS-335; not routed by, the definitions unchanged) makes notification-service >= 0.8.0 also text
    the message to the administrators of the household after the Discord post - for the few
    messages nobody may miss (a lost grid, a planned outage); an SMS costs. Queues have a 1-hour TTL and no dead-letter queue (accepted 2026-10-05): a
    publisher that cares repeats. Publishers: `heating-service` (silent sensors),
    `boiler-service` (the boiler Shelly), `weather-service` (the weather station and its gateway), `light-service`
    (the Shelly lights and the sensors of the occupancy, the empty house), `blinds-service` (the Shelly blinds,
    unconfirmed commands), `amx-service` (the frame server of the AMX master, HAS-309) `appliance-service` (the plugs of the appliances, HAS-280) `weather-service` also the silence of the air quality sensor and, in the `household` category, the smog - HAS-429; `water-service` (the mains water, the water valve and frost - HAS-319; the flow - HAS-320; a circulation that does not warm the return - HAS-405; the water softener - HAS-399) `aircon-service` (an air conditioner not answering - HAS-383), `presence-service` (the detection passes skipped - HAS-476), `safety-service` (the detectors and the base - HAS-463), `gate-service` (the doorbell and the gate, `household` - HAS-452), `safety-service` (the fire alarm, `household` - HAS-461) and `energy-service` (the daily summary - HAS-339; the outages of the grid, by SMS too - HAS-334; the planned outages of Tauron, by SMS too - HAS-337; the silence of its sources and the overload of a phase - HAS-332; the alarms of the SOLAX - HAS-329; the faults of the SOFAR - HAS-330). `GET /home/notification/skippy?message=&level=`
    through a port-forward is the smoke test.
    **A third category, `household`** (definitions 1.4.0, HAS-273): `notification.<env>.household`,
    same TTL, no DLQ, but the payload is the **JSON `HouseholdNotification`** of `smart-home-sdk`
    1.13.0 - words composed by notification-service, in Polish, for the household's own Discord
    channel, SMS (SMSAPI) and Web Push (consumed from HAS-274 on; publishers `appliance-service`, `weather-service`
    (the smog, HAS-429) and `gate-service` (the doorbell and the gate, HAS-452 - on an intercom channel of its own) and `safety-service` (the fire alarm, HAS-461 - texted and pushed to everybody)).
    The VAPID private key and the SMSAPI token are in the secret `notification`; the public key is
    plain env of notification-service and database-service and the two copies change together
    (`deployment-tools/README.md`).
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
  in `/device` and publishes to `amq.topic`; sixteen queues `device.<env>.<domain>` (`prod` /
  `dev` × `weather`, `blinds`, `light`, `heating`, `energy`, `water` - definitions 1.6.0, HAS-314; `gate` - 1.9.0, HAS-443; `safety` - 1.10.0, HAS-460), each bound with `#`: **every queue gets
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
    **One exception, the water valve** (definitions 1.7.0, HAS-314): its XT1 firmware declares its own
    subscription queue whatever `enable_rpc` says, so `shelly` may configure and read that one queue
    (`mqtt-subscription-neowatervalve-b08184e15254qos0/1`) and a topic permission keeps what `shelly` reads from
    `amq.topic` to the topics of the valve; a new device that subscribes gets the same, by its own name.
    **The X-Sense SBS50 base station** of the smoke detectors publishes as the user `xsense`
    (definitions 1.8.0, 2026-11-16; it subscribes on connect, so it has the queue exception of the
    water valve under its own name, its reads kept to `homeassistant.*`) the Home Assistant MQTT discovery of
    its detectors - routing keys `homeassistant.<component>.<station>_<detector>.<entity>.state` -
    which every `device.*` queue gets; safety-service reads it from `device.prod.safety` (definitions 1.10.0,
    HAS-460 - the probe queue of the first days deleted on 2026-11-20).
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
- **ingress-nginx finishes a request its client gave up on** (`proxy_ignore_client_abort on`, the
  controller ConfigMap in `deployment-tools/k8s/ingress-nginx/`, HAS-269): a Shelly Motion Gen1 closes
  the connection about 1 ms after sending its action URL, and nginx had aborted those requests (499)
  before the gateway saw them. Keep it on a reinstall of the controller.
- **Nothing behind the gateway is authenticated**, writes included (a `DELETE` of an Eaton room
  sensor is one call from the LAN). Accepted: access is LAN / VPN only.
- `notification-service` is deliberately not routed. `presence-service` is routed as an
  **allowlist** of its four report reads, `GET` only — `PathPattern` matches the raw path, so a
  `/**` tail would publish `residents/../clients`; **every new endpoint of `presence-service`
  needs a gateway release**. Exposing who is at home was accepted (2026-10-05) — do not
  re-raise, but a new presence endpoint gets its own look at what it exposes.
- `weather-service` is routed the same way (gateway 0.6.0, HAS-239): exactly `GET /weather/current`,
  `/weather/status`, `/weather/history` - it serves reads only; **every new endpoint of
  `weather-service` needs a gateway release** too. A month of history answers in about 0.1 s
  through the ingress.
- `blinds-service` is routed by path, `/blinds` and `/blinds/**`, every method (gateway 0.7.0,
  HAS-251): the Shelly Gen1 rollers call `GET /home/blinds/events/gen1` through the host-less
  ingress - **a `GET` with a side effect by design** (a Gen1 device can only `GET`), an
  idempotent report of a state, so the repeat-once of a broken read is harmless for it.
  `appliance-service` too (`/appliance`, `/appliance/**`, every method - gateway 0.9.0, HAS-281): its reads and
  `POST /home/appliance/{id}/acknowledge`; no `GET` with a side effect. `energy-service` the same way
  (`/energy`, `/energy/**`, every method - gateway 0.10.0, HAS-325), and `aircon-service` (`/aircon`, `/aircon/**`,
  every method - gateway 0.11.0, HAS-379; the service runs since 2026-11-07, HAS-380), and `gate-service` (`/gate`, `/gate/**`,
  every method - gateway 0.12.0, HAS-447): its `GET /home/gate` and **the opening of the gate, `POST /home/gate/open`** - one
  unauthenticated call from the LAN, the accepted state of everything behind the gateway. And `safety-service`
  (`/safety`, `/safety/**`, every method - gateway 0.13.0, HAS-459): the reads of the fire detectors and their alarms;
  no `GET` with a side effect. And `media-service` (`/media`, `/media/**`, every method - gateway 0.14.0, HAS-516):
  `POST /home/media/amplifier/unlock`, which sends the amplifier the file that unhangs it - a write to the house; no
  `GET` with a side effect.
  `light-service` is routed the same way (`/light`, `/light/**`, every method - gateway 0.8.0,
  HAS-265): its `GET /home/light/events/gen1` (Gen1 lights, the Shelly Motion of the sanctum) is the
  second such `GET`. Every other side effect stays off `GET`.
- `database-service` is routed by path with **open tails, on purpose** (every method; what that
  service adds below a routed path is published without a gateway release) — do not propose an
  allowlist; `/device` is listed by branch (`configuration`, `registry`), so a third branch
  needs a gateway change. A pattern ending in `/**` matches the bare path. The full `GET
  /home/household` stays routed (owner, 2026-10-08) — do not re-raise. `/amx/**` routes the
  writes of `amx-service` — the only thing it answers over HTTP since 2.0.0.
- **A broken connection to a service is a 502 with a body, and a `GET` without a body is
  repeated once** when it broke within 1 s (gateway 0.4.0, HAS-212; logged at WARN). The pool
  closes a connection idle for 2 min or older than 30 min (conntrack forgets an idle connection
  after 24 h, which had produced bare 500s). A `POST` is never repeated. The same stale
  connection between services cost one temperature reading after a `database-service` restart —
  accepted (2026-10-11), do not re-raise.
- The gateway takes `spring-cloud-starter-gateway-server-webflux` from the BOM of the Spring Cloud release train
  2026.0.0 (5.1.0, built for Boot 4.2.0) since 0.13.0 (HAS-459); before it the starter was pinned by hand (5.0.4) while
  no train targeted Boot 4.1. **Re-test the gateway on every bump** of Boot or the train anyway (recipe in its
  `CLAUDE.md`: the jar with `home,local` and a stub, no cluster needed); a Boot bump the train does not cover yet waits
  for it.

### Database

- One managed PostgreSQL with **47 connections for the whole cluster** (owner, 2026-10-25: plan
  Basic, 1 vCPU, 2 GB - 22 before), not for this project alone: `ristretto` (another application of
  the owner, namespace `krisoo`) has a database and a pool of **3** there. Split of this project:
  **heating 2 / database 4 / water 2 / presence 2 / blinds 2 / weather 2 / light 2 / appliance 2 /
  energy 2 / aircon 2 / gate 2 / safety 2 — 26 allotted**; with ristretto 29 of 47, so 18 free for Flyway, tools and the next services (the
  shares can be re-cut now; the service CLAUDE.md files that still say "22" are fixed in passing). It is sized for
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
  `NOT_FOUND_DEVICE` of database-service; `OPEN_TOO_SOON` of gate-service, HAS-487) and the dashboard (household and device codes).
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
  (2026-08-13); its chronicle is in `history.md`. Every service is on Boot **4.1.1**, boiler, heating, water and weather on **4.1.2**, aircon, amx, blinds, light and safety on **4.1.3**, api-gateway (with Spring Cloud 2026.0.0), appliance, database, energy, gate, media, notification and presence on **4.2.0**.
- **Spring Boot and the own libraries follow one rule**: when a newer release exists, the
  repository being worked on moves to it in that task (a no-op bump included); the others follow
  with their next task. A mixed fleet after a release is the expected state, not drift to
  report. Libraries with a Boot parent follow it too; a library built on a newer Boot is fine
  for a consumer on an older one (not across the RabbitMQ move of Boot 4.2 - `cholewa-commons` 2.0.0 above).
- **The Maven plugins the Boot parent manages carry no version of their own** (owner, 2026-11-24): `maven-enforcer-plugin`,
  `maven-surefire-plugin`, `versions-maven-plugin` and `maven-dependency-plugin` take the version of the parent; only a
  plugin Boot does not manage (`tidy-maven-plugin`) keeps a property, at its latest. Each repository drops the pins in its
  next task (done: cholewa-commons, energy-service).
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
  - No Spring Cloud release train targeted Boot 4.1 (the BOM was dropped; Eureka is gone anyway); since 2026.0.0 one
    targets Boot 4.2 - the gateway imports it (HAS-459), a service needs it only for a Spring Cloud module.
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
  `@Scheduled` pass shares one `traceId` by itself. **Logbook's lines carry it only through
  `cholewa-commons` ≥ 1.10.0** (HAS-298): the library moves Logbook into the reactive chain (its
  WebFilter on the server, its `ExchangeFilterFunction` on every `WebClient` of the injected
  builder); a service that bumps drops its own `LogbookClientHandler`, or it logs every call twice.
  On the older services the Logbook lines have no `traceId` (the Grafana trace filter is a
  substring match on the line, so it still finds the `traceparent` header of a request between
  two services).
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
  text. `cholewa.required-properties` of `cholewa-commons` ≥ 1.9.0 refuses the start before the
  first bean (weather, blinds, heating, light, amx, boiler - the last copy of `BrokerPasswordCheck`
  went with HAS-306); a copy would run after an ordered post-processor, the library does not.
- **Calling a device or gateway outside the cluster** (HAS-149): pin a self-signed certificate by
  fingerprint (`setEndpointIdentificationAlgorithm("")` to drop hostname verification — `null`
  is ignored); map every failure, the body included (`bodyDelay`, a closed socket, `{}`); keep
  the wire and the domain model apart. Tests use `mockwebserver3`, never the legacy
  `mockwebserver` (JUnit 4 — still in heating); a `MockWebServer` per test, no fixed
  port, no shared connection pool.
- **A publisher is verified as `publisher.as(StepVerifier::create)`** - the only acceptable form in
  every repository (owner, 2026-10-16); never `StepVerifier.create(publisher)`. Older tests are
  converted in the files a task touches (cholewa-commons still has them).
- **Repository tests**: H2 in a `@DataR2dbcTest` slice for portable statements; Testcontainers
  PostgreSQL for PostgreSQL-only SQL (heating and water fail without a Docker,
  `database-service` skips without one — but not where `CI=true`).
- **Code moves into `cholewa-commons` only when more than three services use it** (owner,
  2026-10-11). Up to three copies stay — no review finding, no task; note the copy in each
  service's `CLAUDE.md` (today: `NotificationRabbitConfig`, **nine copies** — heating, blinds,
  weather, light, amx, energy, water, gate, safety: the fourth to the ninth kept by the owner's choice (HAS-257, HAS-309, HAS-334, HAS-319, HAS-452, HAS-461), do not re-raise;
  `BrokerPasswordCheck` moved to `cholewa-commons` 1.9.0 with HAS-235).
- Private **LAN IPs** already in service configs are tolerated (2026-07) — do not flag them.
  Secrets, tokens and credentials remain strictly forbidden in public repos.
- **CI/CD** — GitHub Actions in every repo: `CI.yml` (build + tests), `sonar.yml`, and
  `release.yml` (services: Docker image `magikabdul/<repo>` on Docker Hub) or `package.yml`
  (libraries: GitHub Packages), both on a GitHub release; poms keep a dev version. **The Discord
  message of `CI.yml` carries no commit** (owner, 2026-10-12): one step with `if: always()`,
  built with `jq` and `curl` — copy it from `smart-home-sdk/.github/workflows/CI.yml`. No task of
  its own: convert a repository in the PR of its next task. Converted: `smart-home-sdk`,
  `database-service`, `api-gateway-service`, `shelly-client`, `amx-service`, `blinds-service`, `weather-service`
  (new), `heating-service`, `light-service` (new), `boiler-service`, `presence-service`, `water-service`, `notification-service`, `appliance-service` (new), `energy-service` (new), `aircon-service` (new), `gate-service` (new), `safety-service` (new), `media-service` (new); 5 repositories still have the old form.

## Working rules for Claude

- **Spring Boot services and libraries**: the user writes the code themselves. Do NOT write
  or modify code there unless explicitly asked. Default contributions: analysis, code
  review, security review, answering questions.
- **`web-application`**: full autonomy — Claude designs and implements the frontend.
- **`amx`**: NetLinx language; analysis and suggestions, ask before modifying. The owner
  writes the NetLinx code and transfers it to the masters.
- Never commit or push unless explicitly asked.
- **Jira statuses (owner, 2026-11-26).** When Claude starts working on a HAS task that is in "To Do", it moves the task
  to "In Progress" itself and says so in one line; once its quality gate passed and the DoD is ticked, Claude asks
  whether to move it to "Done" and does so only on the owner's yes (2026-11-26). Every other column stays the
  owner's, and a task in another column is left as it is. **No sentence about a Jira status goes out without a
  read of that issue in the same turn** - what the status is, that Claude did not change it, or what is left to move;
  a status not read in this turn is not mentioned at all, and "as of my last read" is no substitute. Claude never tells
  the owner to move a task. The owner works in Jira in parallel; the same holds for a PR, a pod or a release named in a
  summary - re-read at the source right before reporting.
- **A standing rule the owner gives goes into git** (owner, 2026-11-26): this file for a rule of the whole project, the
  `CLAUDE.md` of a repository for one of that repository - not only into Claude's local memory, which is lost with a new
  system or another machine.
- **Java services and libraries (owner, 2026-10-22): the owner reviews a change of Claude in IntelliJ
  before it is pushed** - Claude leaves it **uncommitted** on the local `feature/HAS-<n>` branch (a local
  commit hides the changes from the Git tool of IntelliJ), names the files and
  waits for the go-ahead; the Sonar findings the IDE shows are fixed before the push, and the PR and CI
  come after. A version bump names where the version was seen (start.spring.io can lag Maven Central).
- **All changes to Spring services, libraries, `web-application` and the NetLinx code of
  `amx` go through pull requests** — no direct commits to `main`. Branch naming:
  **`feature/HAS-<n>`**, where `<n>` is the Jira task number (HAS project). When no Jira
  task covers the change, create one first (`jira-backlog`) or confirm with the user how to
  proceed.
  - **`amx` (owner, 2026-10-14): `/code-review` alone** before a PR is called ready
    (`service-review` is written for Spring). Since 2026-11-22 its `main` is protected like
    the service repositories, so documentation-only changes go through a pull request too; a
    modified workspace file (`.apw`) is committed with the next change of the repository.
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
