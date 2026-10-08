# Smart Home Automation System — organization context

Solo-developer project: a set of repositories under the GitHub organization
[smart-home-automation-system](https://github.com/smart-home-automation-system) that together
control a real smart home — an AMX/NetLinx control system with Eaton wireless devices, and
Shelly Wi-Fi devices. The backend runs on a Kubernetes cluster. All repositories are public
except `deployment-tools`.

## Repository map

### Spring Boot microservices (all reactive — WebFlux)

| Repository | Local port | Purpose |
|---|---|---|
| `api-gateway-service` | 6200 | Spring Cloud Gateway — the **only** entry point into the cluster from outside: the ingress forwards all of `/home` here and static routes fan out to the services over k8s DNS (HAS-171) |
| `amx-service` | 6001 | Bridge to the AMX control system (2-way communication with AMX-connected devices) |
| `heating-service` | 6002 | Heating control; since 1.5.0 (HAS-94) it also watches the temperature sensors and raises a notification when one has been silent for 24 h. Since 1.7.0 (HAS-169) every Shelly call has a connect and a response timeout, and a relay that fails is skipped instead of ending the pass of its room. Current release **1.7.1** |
| `notification-service` | 6003 | Notifications: consumes the `alert` and `info` queues and posts each message on the Discord channel `alerts` as an embed colored by its level (HAS-94). The two queues keep a listener each, in one class (`RabbitNotificationConsumer`) — **two containers on purpose**: one listener on both queues was tried in HAS-179 and dropped, because a container only warns when one of its queues is missing, a publisher can overwrite the `amqp_consumerQueue` header the default level would be read from, and a shared channel redelivers the unacknowledged messages of both. Current release **0.4.3** |
| `ai-service` | 6004 | AI integration |
| `database-service` | 6005 | Persistence facade for other services: Eaton device configuration and the household registry (members + their Wi-Fi devices, read by `presence-service`; HAS-150 — and, since 0.9.0, each member's role and rooms, read by the web dashboard; HAS-192 — which, since 0.10.0, asks for them through a read of its own, `GET /home/household/profiles`; HAS-211). Current release **0.10.0** |
| `water-service` | 6006 | Water control |
| `boiler-service` | 6007 | Boiler control: drives the furnace and both pumps as relays of one Shelly Pro 4. Since 1.3.0 (2026-10-07, HAS-109) it also tells the household when that Shelly stops working — an alert once its calls have been failing for 5 minutes, a reminder every hour, an info when it works again — which makes it a publisher on the `/notification` virtual host. Current release **1.3.0** |
| `shelly-cloud-service` | 6008 | Shelly cloud integration — a **skeleton**: builds, starts and serves its Actuator, but has no endpoints and makes no cloud calls yet. Own repo in the org since 2026-08-13, on the target toolchain and deployed since 0.1.0 (HAS-129). Current release **0.1.1** |
| `presence-service` | 6009 | Household presence monitoring (epic HAS-147). It reads the clients connected to the home network from the UniFi gateway (0.2.0, HAS-149) and, since 0.3.0 (2026-10-01, HAS-151), runs the presence engine: every minute it matches them against the household registry of `database-service`, and a member whose devices all stay unseen for 10 minutes becomes ABSENT, dated from the last sighting. Status changes are stored in its own database (`home-automation-presence`) — a row per change, a confirming pass only moves `last_checked_at`. The state lives in the memory of one instance, so the Deployment uses `Recreate` and must not be scaled. Since **0.4.0** (2026-10-05, HAS-152) it has a reporting API: `GET /home/presence/residents/presence` (every active member with `present`, `since`, `lastCheckedAt`) and `GET /home/presence/residents/{name}/report?from=&to=` (the periods at home within a range of at most 366 days, local date-times, the one still going on marked `open`) — residents are identified by **name**, there is no id. **0.5.0** (2026-10-05, HAS-153) added the aggregates: `GET /home/presence/residents/{name}/report/daily` (per day `secondsAtHome`, `firstArrival`, `lastDeparture`, `presencePercentage`) and `GET /home/presence/house/report` (one timeline of occupied / empty stretches, per day `secondsOccupied`, `secondsEmpty`, `wasEmpty`). Both cover only what was observed and name the bounds (`observedFrom`, `observedUntil`); a member inside their grace period keeps the house occupied (the report asks the tracker), while an outage across a status change still reads as empty — know that before acting on `wasEmpty`. All four reports are routed by the gateway; the diagnostic `GET /home/presence/clients` (every MAC address on the network) is deliberately **not**. **0.6.0** (2026-10-05, HAS-154) closed the scope of the epic with the retention: every night at 03:00 the rows **last checked** more than `presence.retention` ago (`P365D`; 7 days to ten years, a bare number is days) are deleted — by the last check, so the current row of a watched member always survives — and the statistics never count anything before that horizon as observed. Current release **0.6.0**; notifications are not planned yet |

Do not confuse `api-gateway-service` (HTTP edge / Spring Cloud Gateway) with
`amx-service` (AMX hardware bridge).

### Shared libraries (Maven, `cloud.cholewa` group)

| Library | Purpose | Current consumers |
|---|---|---|
| `cholewa-commons` | Common utilities | ai, amx, api-gateway, boiler, database, heating, notification, presence, shelly-cloud, water |
| `cholewa-security` | Security/auth | none yet — kept for possible future auth in `api-gateway-service` |
| `smart-home-sdk` | Shared domain / API models | amx, boiler, database, heating, presence, shelly-cloud, water |
| `shelly-client` | REST client for Shelly devices | boiler, heating, shelly-cloud, water |

`cholewa-commons` and `cholewa-security` are intentionally hosted on the personal
`magikabdul` GitHub account (not the org): they are also used by services outside this
project. Their packages come from `maven.pkg.github.com/magikabdul/*` (pom server id
`github-prv`); the org libraries use `.../smart-home-automation-system/*`
(`github-org-smart-home`). Do not propose moving them into the org.

### Other repositories

- `amx` — AMX/NetLinx sources for the physical control system (not Java). Like
  `cholewa-commons` and `cholewa-security`, this one lives on the personal `magikabdul`
  account (`magikabdul/amx-tenczynek`), not in the org — the workspace directory is named
  `amx`.
- `web-application` — the dashboard: Angular 22 + Angular Material frontend (desktop-first,
  responsive; on the household's iPhones the same application installed as a PWA, no native
  app). Claude has full autonomy here, but every change goes through a feature branch and a PR
  reviewed and merged by the user. Current release **0.6.1** (2026-10-08, HAS-211 — the
  profiles come from `GET /home/household/profiles` instead of the whole registry, and one
  way to the browser's storage) on top of 0.6.0 (HAS-193 — household
  profiles: personal links, a profile picker and navigation by role), 0.5.0 (HAS-209 —
  a real photo behind each view, the first one for the Overview, and the look tuned with the
  owner on the live page), 0.4.1 (HAS-210 — two fixes of the look: the domain badge icon centred,
  the glow on a layer that iOS Safari's toolbar does not move), 0.4.0 (HAS-208 — the "Zorza"
  look), 0.3.0 (HAS-190 — the MUI look and the seasonal colours), 0.2.0
  (HAS-189 — the interface in English and Polish) and 0.1.0 (HAS-188 — the application shell
  and the delivery pipeline), deployed; the
  dashboards follow from the Jira
  plan (epics HAS-184 foundation, HAS-185 heating / hot water / boiler room, HAS-186 personal
  room view on the phone, HAS-187 presence and household administration; frontend tasks carry
  the label `frontend`, the backend tasks they wait for sit in the same epics). What is decided
  (details in the repo's `CLAUDE.md`):
  - **One host for the application and the API**, reachable on the LAN / over VPN only: its own
    Ingress (manifest in `deployment-tools/workshop/`, like the services) sends `/home` to
    `api-gateway-service` and everything else to the application, so the browser calls the API
    on its own origin — no CORS, no gateway change. Consequence: **no application route may
    start with `/home`**, and the host-less `smart-home-ingress` used by the AMX controller is
    left alone.
  - **Not a Spring service**: an `nginx-unprivileged` container on **8080**, probes on
    `/healthz`, no Actuator and no Prometheus annotations; access logs are JSON on stdout, so
    Loki parses them with `| json` under the same `app` label. Image
    `magikabdul/web-application`, built inside a multi-stage `Dockerfile`; CI builds the image
    and tests it in a real browser before it can be released (the nginx configuration and the
    Content-Security-Policy have no other test).
  - **The same Definition of Done as a service**, fitted to the frontend: `/code-review` and
    `/security-review` (no `service-review` — that one is for Spring) recorded on the PR,
    verification in a browser with screenshots, then release and deploy in every task.
  - Data via polling of the gateway behind a per-domain data-access layer (SSE-ready); a mock
    API for development and browser tests, which therefore can never switch a real device.
  - Household-member profiles without login, chosen by a personal link; a member's **role and
    rooms live in the household registry** (`database-service`), not in frontend code. The
    separation of roles is UI-only until the gateway validates tokens (two phases, accepted by
    the owner on 2026-10-06 — access is LAN / VPN only). Residents only **view** temperatures
    and schedules; setting them is the admin's alone.
  - **The profiles exist since 0.6.0** (HAS-193). `/u/<name>` — the name of the registry, in
    any case — opens a profile and the browser remembers it with its role and rooms; without
    one every address leads to a picker of the active members. The administrator reaches every
    page; a resident reaches `/room` ("My room", so far only the list of their rooms — the view
    proper is HAS-202) and is led there from everything else. The registry is asked again at
    every start and whenever the page comes back into view, so a role changed there, or a
    member switched off, takes effect under an open page; while the backend is away the
    application keeps working as the member it remembers. **A page of the application is the
    administrator's unless its route says otherwise** (`data.access`). The language is now
    remembered per member. Two things the owner settled or accepted (2026-10-07): a resident
    is not offered the picker, so a profile chosen by mistake where there is no address bar
    (the installed application) is undone by clearing the data of the site; and Settings and
    About are the administrator's. The README of the repository says plainly that none of this
    is access control.
  - **The dashboard asks for the profiles only** (0.6.1, HAS-211, 2026-10-08). Until then every
    browser downloaded the whole registry — phone numbers and device MAC addresses included —
    to learn one member's role. `database-service` 0.10.0 serves `GET
    /home/household/profiles`: the active members only, each with `name`, `role` and `rooms`
    (left out when empty), sorted by name — the model is `HouseholdProfile` of `smart-home-sdk`
    1.5.0, a schema of its own, so a field added to `HouseholdMember` later does not reach the
    browsers by itself. The gateway needed no change (`/household/**` was routed already), which
    also means the full `GET /home/household` is still reachable through it — **kept on purpose** (owner, 2026-10-08: the network is local, and the route is what makes the whole registry callable from Bruno without a port-forward; do not re-raise it). The application
    never calls it — its mock API answers that path with 404, so a browser test fails on a call
    that slips back in. "Switched off" and "removed" are one case to the application now: a
    member who is not in the answer loses the profile. Not shown on live data: the registry held
    no switched-off member at the deploy, and the repository of `database-service` is mocked in
    its tests (HAS-207), so the first member switched off is the first proof of the filter.
    With the same release the application got one way to `localStorage`
    (`core/storage/browser-storage.ts`) instead of a copy per store.
  - **Two languages since 0.2.0**: English by default — on a first visit always, whatever the
    browser says — and Polish chosen in the toolbar, without a reload, remembered in the browser
    (Transloco; English in the bundle, Polish downloaded on choice). Three things it settled,
    with the owner's word on the first two (2026-10-06): English formats dates as **en-GB**
    (24-hour clock); a **temperature is written with its symbol**, `°C`, never through `Intl`'s
    unit style, which prints Polish degrees as `st. C`; and **text from outside is never a
    translation parameter** — Transloco searches the substituted text for placeholders again,
    so a backend message containing `{{ message }}` froze the tab until such text was printed
    literally. The backend's own messages stay in English, as everywhere.
  - **The look is "Zorza", the colours follow the season** (0.4.0, HAS-208; the MUI look of
    0.3.0 / HAS-190 lasted a day). The owner chose it on 2026-10-07 from a style study of five
    directions: a deep page glowing softly in the two colours of the season, cards of frosted
    glass (`backdrop-filter`), a fixed colour per domain of the house (heating, hot water,
    boiler room, household — the same in every season), the navigation in a panel on the left
    (a bar on top and a bottom bar on the phone), Plus Jakarta Sans self-hosted. The framework
    stays Angular — the components are Angular Material, restyled through their CSS variables
    only (`src/theme/_zorza.scss` the look, `_seasons.scss` the colours), so nothing was
    rewritten. Four palettes (spring green, summer gold, autumn rust, winter blue — summer was
    sea-teal and indistinguishable from winter), each light and dark, picked by `data-season`
    on `<html>` from the browser clock (21 Mar / 22 Jun / 23 Sep / 22 Dec), re-read at midnight
    and at least hourly. A Settings page previews any season and scheme; since the profiles
    (0.6.0) it is the administrator's. WCAG AA contrast of all eight variants is a build check
    (`npm run check:contrast`), in CI — since 0.4.0 on the **composited** colours (glass over
    the glow, the domain wash), because a translucent surface has no contrast of its own. One
    thing it taught: Material's component styles are appended after the application's
    stylesheet, so a rule of equal specificity on a Material class silently loses — restyle
    through the variables, or with a selector that carries Material's own class.
  - **A real photo behind each view** (0.5.0, HAS-209): a route names its photo, the shell paints
    it under the glow with a haze of the page colour, the Overview got a generated house at blue
    hour (Superdesign, prompt and model recorded in the repo), and every later view brings its
    own photo in its own task; a switch in the Settings turns the photos off. What the first
    photo taught: translucent glass over a photo is a contrast problem — the check now lays the
    text over the darkest and the lightest patch of every photo, and the owner tuned the haze,
    the glass and the type scale on the live page (thin haze, see-through cards, a 14 px root,
    12 px corners, no lead sentence under a title). Three decisions of the owner stand: the
    glass stays as thin as the contrast allows, the title lies on the bare photo (checked over
    the top band of the picture) and the phone typography is judged on the real iPhone, not an
    emulated one.
- `deployment-tools` — **PRIVATE**: Kubernetes manifests, local `kind` cluster setup,
  pipelines, RabbitMQ config. Private infrastructure details belong here, never in
  public repos.
- `organization-repository` — local clone of the org's `.github` repo: organization
  profile README and this shared Claude configuration (`claude/`).
- `claude-tooling` — Claude Code plugin marketplace with the `smart-home` plugin
  (org skills — see `claude/skills.md`).
- `tenczynek-network-setup` — **PRIVATE**: home network setup; dormant (last change
  2022), not cloned in the workspace.

## Architecture notes

- Reactive stack everywhere: Spring WebFlux, no blocking calls in service code.
- Async messaging via RabbitMQ: `amx-service`, `heating-service`, `notification-service` and,
  since HAS-109, `boiler-service` (a publisher of notifications only).
  Two virtual hosts, one broker user each: `/temperature` (user `temperature`; `amx-service`
  publishes `TemperatureMessage` to the fanout exchange `temperature.events`,
  `heating-service` consumes `temperature.prod.heating`) and `/notification` (user
  `notification`; the **headers** exchange `notification` routes by the `category`
  (`alert` / `info`) and `env` (`prod` / `dev`) headers into `notification.<env>.<category>`,
  the routing key is ignored, and the payload is **plain text** — `notification-service`
  reads it as a `String`). The queues there have a one-hour TTL and no dead-letter queue
  (accepted by the owner on 2026-10-05): a notification that cannot be delivered ends in the
  log at ERROR, so a publisher that cares repeats it. The exchanges, queues and bindings come
  from the broker definitions in `deployment-tools`, no service declares them. The secret
  `rabbitmq` holds one key per broker user, `<user>-password`; user names are not secrets
  (`amx-service` gets `temperature` as a plain value in its manifest).
- **A RabbitMQ connection is named after its pod** (HAS-106, 2026-10-06; `amx-service` 1.3.1,
  `heating-service` 1.7.1, `notification-service` 0.4.3): the management UI shows
  `heating-service-69bccdf7f9-xzfxt`, which tells the old pod from the new one during a
  rollout. Each service has the same small `ConnectionNameStrategy` bean in its `RabbitConfig`
  — four copies with `boiler-service` (1.3.0), accepted by the owner for now; moving it into
  `cholewa-commons` is HAS-205, the adoption HAS-206. It takes
  `HOSTNAME` **only when it starts with `spring.application.name`**: outside Kubernetes the
  variable is not simply missing — Git Bash, Linux shells and plain Docker set it to a
  workstation name or a container id, and an empty value bypasses a placeholder default —
  so everything else becomes `<service>-local`. A second connection of the same pod adds what
  it is for (`<pod>/notification` in `heating-service`, opened on the first publish). A new
  service that talks to the broker copies the bean.
- **The boiler room Shelly is watched (HAS-109, `boiler-service` 1.3.0, deployed 2026-10-07).**
  `ShellyAvailabilityMonitor` is told by `ShellyClient` how every call ended and is asked at
  the end of every control pass. The numbers are the owner's: alert (`error`) after 5 min,
  reminder (`warn`) every hour, one `info` on the return; "urgent" is the red alert on Discord
  until the SMS library exists (HAS-68). What four review passes taught, worth carrying into
  any monitor of a device:
  - **Judge by whole passes and by kind of call, not by single calls.** A pass with any failed
    call is a failed pass; a pass proves the device only when it answered the kind of call
    (status, command) that had been failing — or when it answers and nothing has failed for the
    limit, because a command is sent only when a relay has to change. Call by call, a device
    that answers its status and refuses every command is never reported, and a flapping one
    sends a green/red pair every few minutes.
  - **Time alone proves nothing.** An alert takes a failure in the pass it follows, and a
    failure nothing followed for the limit is forgotten.
  - **The device and the broker go down together** (power, network). An outage whose alert
    never got through is announced afterwards, with the news of the return.
  - **JSON that is not the model is a failed call** here too: `{}` decoded into an object of
    nulls and read as "the relay is off".
  - **A notification must neither fail nor stall what it reports on**: the report swallows
    every error and is cut off after 30 s. Accepted by the owner (2026-10-07): a broker that
    confirms later than 10 s gets the same message again with the next pass, and a hanging
    broker delays the next pass by up to those 30 s.
  - **A publisher with one connection needs no second factory**: `boiler-service` points
    `spring.rabbitmq.*` straight at `/notification` and uses the auto-configured template;
    confirms, returns and `mandatory` are properties, pinned by its context test. The
    connection is opened by the first publish, so a wrong password would show only with the
    first alert: after a deploy `GET /actuator/health` on the management port forces it (the
    RabbitMQ indicator is in the aggregate, not in the `readiness` / `liveness` groups).
  - **Nothing in the service can force a publish** — an endpoint would be reachable through
    the gateway. The route was proven before the release by running the jar outside the
    cluster with the Shelly pointed at a dead address, `env: dev` and a short limit, and
    reading the message back from `notification.dev.alert`, which nothing consumes.
- **Silent temperature sensors (HAS-94, released and deployed on 2026-10-05: `heating-service`
  1.5.0 → **1.6.0**, `notification-service` 0.3.0 → **0.4.1**).** `heating-service` checks once an hour
  the last stored reading of every room: silent for 24 h → an `alert`, repeated every 24 h,
  and one `info` when readings return; the state is a row per silent sensor in
  `temperature_sensor_alert`, and `heating.sensor-monitor.muted-rooms` takes a retired sensor
  out. `GET /home/heating/temperature/sensors` lists `room`, `lastReadingAt`, `stale`,
  `muted` (covered by the gateway's `/heating/**` route). With it `heating-service` becomes a
  **publisher** on `/notification`, over a second connection — and `notification-service`
  finally forwards its queues to the Discord channel `alerts` (until then it only logged
  them). Every message carries a third header, `level` (`error` / `warn` / `info`), which the
  broker does not route by: `notification-service` posts the message as one Discord **embed**
  — the level is the title, the text the description, the bar red, yellow or green — and a
  missing or unknown level falls back to the queue (alert → `ERROR`, info → `INFO`). The
  first alert about a sensor is an `error`, its reminders are `warn`, the recovery `info`.
  The first run found a real one: the sensor of `bathroom down` had been silent since
  2026-08-21. Six things it taught, worth checking in every service that publishes, consumes
  or talks to Discord:
  - A second RabbitMQ connection must **not be a bean**. Any `ConnectionFactory` or
    `RabbitOperations` bean makes `RabbitAutoConfiguration` back off, and the existing
    listener loses its auto-configured connection with everything `spring.rabbitmq.*` sets
    on it. Build the factory and the template by hand inside the publisher's bean method and
    switch observation on there (`setObservationEnabled` + `setApplicationContext`).
  - A `send` that returns proves nothing: the broker confirms an unroutable message too.
    Publishing that drives state needs correlated confirms **and** mandatory returns, and
    the state is written only after both say the message is in a queue.
  - A `@RabbitListener` returning `Mono` that signals an error makes the container hand the
    message back, and the broker redelivers it at once — a tight loop for as long as the
    downstream is unavailable. Retry inside the chain with a backoff, only what another
    attempt can change, then log the message and complete. discord4j hides its answers from
    such a filter: a 5xx arrives wrapped in Reactor's "retries exhausted" after its own
    retries, so the check has to walk the causes.
  - **Never let discord4j list a server's channels.** `notification-service` 0.3.0 looked the
    `alerts` channel up by name and delivered nothing: discord4j 3.3.2 could not decode one
    of the channels (`Optional cannot be cast to Id` in `ChannelData`), and one undecodable
    channel fails the whole listing. It showed in production, on the first alert, because no
    test talks to Discord. Since 0.3.1 the channel is configured by id
    (`discord_alerts_channel_id` in the manifest, not a secret) and the message is posted
    straight to it, which decodes only the reply to the post.
  - **What cannot be tested gets tested in the minute after the deploy.** Three things here
    were unprovable by unit tests — the publish against a real broker, the Discord call, the
    look of the message — and two of them were wrong on the first try. `GET
    /home/notification/skippy?message=…&level=…` through a port-forward is the smoke test;
    run it before the first real message is due, not after.
  - **The look of a Discord message is the owner's call, made on a real message.** 0.4.0
    posted the text as plain content with a small embed holding only the level, to keep a
    push preview and to survive a missing "Embed Links" permission; on the channel it read
    poorly, and 0.4.1 puts the text inside the embed. Both costs were checked and are fine:
    the bot has the permission, and the phone notification shows the text. An embed-only
    message is refused as empty without that permission — remember it if the bot is ever
    re-invited.
- Service discovery: Kubernetes-native (k8s Services + DNS). Eureka is gone —
  `service-discovery` was archived and removed from the cluster on 2026-08-13.
- External traffic: k8s ingress (`/home`) → `api-gateway-service` → internal services. The routes
  are static, in `internal.service.*`; two things about them are counter-intuitive and were verified
  in the gateway sources during HAS-171: `PathRoutePredicateFactory` **prepends**
  `spring.webflux.base-path` to every pattern and matches the full raw path (so predicates are
  written without `/home`, but nothing is stripped at runtime), and `RouteToRequestUrlFilter` merges
  **only scheme, host and port** onto the incoming URI — the path part of a route's `uri(...)` is
  discarded, so a target mounted elsewhere needs `rewritePath`, not a longer URI string.
  `notification-service` is deliberately not routed: its `/home/notification/skippy` endpoint has no
  external consumer. `presence-service` is routed as an **allowlist** (gateway 0.3.0, HAS-152;
  four reads since 0.3.1, HAS-153) — exactly its report reads, `GET` only — because it also serves `/home/presence/clients`,
  which must stay inside: `PathPattern` matches the raw, un-normalised path, so a `/**` tail
  under `/presence/residents` would have matched `residents/../clients` and published every
  endpoint added there later. So **every new endpoint of `presence-service` needs a gateway
  change and release of its own** to be reachable from outside. Nothing behind the gateway is authenticated; exposing who is at
  home, with a year of history, to whoever reaches the ingress was **accepted by the owner on
  2026-10-05** — do not re-raise it in reviews, but a new presence endpoint still gets its own
  entry and its own look at what it exposes.

## Pending architecture changes (decided 2026-07, executed by the user)

- `service-discovery` (Eureka) — **done**: archived on GitHub and deleted from the cluster
  on 2026-08-13, k8s DNS covers discovery. The gateway's Eureka client and discovery locator
  went with it in HAS-170 (released 0.1.0), which also ended the failed heartbeat every 30 s
  it had been logging since the server disappeared — the Grafana "Error log spike" alert
  dropped the `!= DiscoveryClient` filter that existed only to hide that noise. HAS-171 finished
  the job (released 0.2.0, 2026-08-13): every service now has an explicit route over k8s DNS,
  the ingress keeps only `/home` and `/rabbit`, and the stale `networking.yaml` — a second
  Ingress object with the same name in the same namespace — is gone. **So the entry is closed**,
  and two long-standing untruths went with it: the gateway's own water routes had never worked
  (they targeted `/water/hot` and `/water/management`, paths `water-service` does not expose)
  and `boiler-service` had no way in at all.
  `water-service` is **done** (HAS-127): its Java 21 migration
  dropped the Eureka client together with the whole Spring Cloud BOM, because the 2025.1.x
  release train is built against Boot 4.0.7 and no Boot 4.1 train exists yet — the service
  used no `DiscoveryClient`, `@LoadBalanced` or `lb://` URIs, so the removal was
  configuration-only. Expect the same forced choice in every remaining Spring Cloud
  consumer. `boiler-service` is **done** as well (HAS-128, same configuration-only
  removal), and it made the gateway side of this concrete: it had no way in from outside until
  HAS-171 gave it one.
- `cholewa-security` — stays; possible future use for auth in `api-gateway-service`.
- **Toolchain migration**: all existing services and libraries move from
  Java 17 / Spring Boot 4.0.1 to Java 21 / Spring Boot 4.1.0. Until a repo is migrated,
  its pom and README badges may still show the old versions.
  Progress: `cholewa-commons` migrated and released as **1.0.0** (2026-07-22, HAS-117) —
  a breaking release (Java 21 bytecode, Jackson 3); consumers stay on 0.2.x until their
  own migration. It has since had ten releases — **1.0.1** (2026-07-23, HAS-131 —
  select `ExceptionProcessor` by exception hierarchy, not exact class), **1.1.0**
  (2026-07-24, HAS-132 — log handled errors in every `ExceptionProcessor`), **1.2.0**
  (2026-07-26, HAS-137 — render database integrity violations as 400 instead of 500),
  **1.3.0** (2026-08-13, HAS-146 — the shared R2DBC connection configuration, see the pool
  note below), **1.3.1** (2026-08-13, HAS-146 — ship the configuration metadata for the
  `database.*` group, so consumers stop hand-maintaining
  `additional-spring-configuration-metadata.json`), **1.4.0** (2026-09-07, HAS-150 —
  answer 409 instead of 400 on a unique-constraint violation, because a broken unique is a
  conflict with existing state, not a malformed request; **only `DuplicateKeyException`
  moved** — `DataIntegrityViolationException` keeps the 400 it got in 1.2.0), **1.5.0**
  (2026-09-27, HAS-150 — the pool validates every connection on acquire, see the pool note
  below), **1.5.1** (2026-09-27, HAS-150 — validation bound 2 s instead of 5 s, and the docs
  describe the actual, gradual recovery), **1.6.0** (2026-10-06, HAS-180 — Bean Validation
  messages pinned to the root bundle, English for the built-in constraints, see the error
  message convention below; also the first library release built on Boot 4.1.1) and **1.7.0**
  (2026-10-06, HAS-174 — an optional machine-readable `code` in `ErrorMessage` and
  `DownstreamErrors.read`, see the error contract note below); current
  latest is **1.7.0**, on `database-service` (0.8.0, 2026-10-06, HAS-175), `amx-service` (1.3.0, 2026-10-06, HAS-176),
  `boiler-service` (1.2.1, 2026-10-06, HAS-181), `ai-service` (0.2.1, 2026-10-06, HAS-182),
  `shelly-cloud-service` (0.1.1, 2026-10-06, HAS-183), `heating-service` (1.7.0, 2026-10-06,
  HAS-169), `water-service` (0.5.1, 2026-10-06, HAS-169) and `notification-service` (0.4.2,
  2026-10-06, HAS-179) — every other consumer takes it with its next task.
  **1.5.1** is on `presence-service` (0.6.0) and `api-gateway-service` (0.3.1). They move to the latest release with
  their next task — the rule is that a service always carries the latest release of the own
  libraries, no-op or not. Every service with a connection pool is on 1.5.1 or later since
  `water-service` 0.5.0 (2026-10-04), so all four validate their connections on acquire.
  `cholewa-security` migrated and released as **1.0.0**
  (2026-07-22, HAS-118) — Java 21 bytecode (no code / no Jackson to migrate); no
  consumers yet, so no coordinated bumps needed. `smart-home-sdk` migrated and
  released as **1.0.0** (2026-07-23, HAS-119) — Java 21 + Jackson 3 (dropped
  `jackson-databind`, generated models keep `com.fasterxml.jackson.annotation` only),
  which closed the 4 Dependabot jackson-databind alerts. `database-service` adopted it
  during its own migration (HAS-126); `shelly-cloud-service`, the last consumer on the old
  SDK (0.1.x), moved during its own migration (HAS-129), so nothing is left behind.
  It has since had five feature releases — **1.1.0** (2026-07-28, HAS-136 — `required` on
  the Eaton configuration models, so the generated models carry `@NotNull` and a consumer
  can validate the payload with `@Valid` alone), **1.2.0** (2026-09-27, HAS-149 — the
  household registry models `HouseholdMember` and `MemberPhoneDetails`, with the schema's
  bounds as `@Size`/`@Pattern`), **1.3.0** (2026-09-27, HAS-150 — the member's phone in
  **E.164**, `+48505602702`, because it is an SMS recipient (SMSAPI); strictly a tightening
  of the 1.2.0 contract, released as a minor because nothing had shipped on 1.2.0) and
  **1.4.0** (2026-10-07, HAS-191 — a member's `role`, the new enum `MemberRole` (`admin` /
  `resident`), and `rooms`, a `List<RoomName>`; both optional, the contract of the web
  dashboard's profiles). Two decisions of the owner there, against the first wording of the
  task and worth repeating in any model that is the body of a partial update: **`role` has no
  default** — a field with a default reads the same whether the caller left it out or sent
  it, so a `PATCH` of the phone alone would have turned an admin into a resident (`active`,
  default `true`, is why `database-service` has separate activate / deactivate operations);
  a missing role is `null` and the registry decides. And **`rooms` is a list, not
  `uniqueItems`** — that generates a `Set` whose setter needs a `jackson-databind` annotation
  the SDK does not have, and without it Jackson fills a `HashSet`, losing the order (for
  enums it differs between JVM runs); a repeated room is for the registry to refuse. What
  could not be helped: a missing `rooms` reads as an empty list — which is why
  `database-service` gave the rooms an endpoint of their own instead of honouring them in
  `PATCH` (below). The SDK got its first tests and a `CLAUDE.md` with these traps.
  **1.5.0** (2026-10-08, HAS-211) added `HouseholdProfile` — name, role and rooms, what the
  web dashboard may know about a member — purely additive;
  current latest is **1.5.0**, on `database-service` (0.10.0, 2026-10-08, HAS-211); the
  others take it with their next task (`presence-service` on 1.3.0 was run against the JSON
  of 1.4.0: it ignores the new fields). **1.3.0** is on `amx-service` (1.3.0), `presence-service`
  (0.6.0), `heating-service` (1.7.0), `water-service` (0.5.1), `boiler-service` (1.2.1,
  HAS-181) and `shelly-cloud-service` (0.1.1, HAS-183).
  **`database-service` 0.9.0 (HAS-192, deployed 2026-10-07) stores and serves both.**
  `GET /home/household` answers every member with a `role` (always) and `rooms` (left out
  when empty — read a missing `rooms` as none); `POST` takes both, and a member registered
  without a role is a `resident`; `PATCH` changes the role only when the body names one and
  never the rooms; **`PUT /home/household/member/{name}/rooms`** replaces them with a JSON
  array in display order (`[]` clears). A room listed twice or `null` among them is a 400
  with the code `INVALID_HOUSEHOLD_MEMBER`; an unknown role or room is a 400 `Malformed
  request body` naming the value, without a code. Stored as the constant names (`ADMIN`,
  `LIVING_ROOM`), the rooms in an array column (`V11`) — so **renaming or removing a
  `RoomName` or `MemberRole` constant needs a migration of the rows there**, or reading the
  registry fails (true of `eaton_devices` since ever). Two things a client has to respect:
  every write is the whole row, so the calls for one member go **one after the other**
  (`PATCH` and `PUT …/rooms` fired together can undo each other, both answering 200); and
  nothing automated tests the array mapping yet (HAS-207, Testcontainers). The migration was
  rehearsed the way worth repeating for any migration: the **released image** against a
  throwaway PostgreSQL in Docker (it applies the migrations so far and writes rows through
  its API), then the new build against the same database — never a local run, which talks
  to the production database. The container has to speak SSL: `cholewa-commons` connects
  with `sslMode` `REQUIRE`.
  `shelly-client` migrated and released as **1.0.0**
  (2026-07-23, HAS-120) — Java 21 + Jackson 3 (dropped `jackson-databind`;
  a model-only library, generated models keep `com.fasterxml.jackson.annotation` only),
  which closes its 4 Dependabot jackson-databind alerts. `water-service` is its first
  consumer on 1.0.0 (adopted during HAS-127), `heating-service` the second (HAS-123) and
  `boiler-service` the third (HAS-128) and `shelly-cloud-service` the fourth and last
  (HAS-129), which leaves no consumer on the old client (0.0.x).
  The first **service** migrated is `notification-service` — Java 21 / Spring Boot 4.1.0,
  released **0.1.0** (2026-07-24, HAS-124). It does not use `smart-home-sdk` or
  `shelly-client`; during the migration it adopted `cholewa-commons` 1.1.0 (a new consumer
  of that library). The second service migrated is `ai-service` — Java 21 / Spring Boot 4.1.0,
  released **0.1.0** (2026-07-24, HAS-125), from an outlier Spring Boot 3.3.4. It uses
  neither `smart-home-sdk` nor `shelly-client` and adopts `cholewa-commons` 1.1.0 as a new
  consumer, wiring its `GlobalErrorExceptionHandler` for consistent error responses like
  `notification-service`. Its AI framework changed from
  **langchain4j to Spring AI 2.0.0** — langchain4j's Spring Boot starter (1.x) is not Boot 4
  compatible, whereas Spring AI 2.0.0 targets Boot 4.1 / Spring Framework 7 — so the service
  now calls OpenAI through a reactive Spring AI `ChatClient`. The third service migrated is
  `database-service` — Java 21 / Spring Boot 4.1.0, released **0.2.0** (2026-07-25, HAS-126),
  deployed and verified on the cluster; it has since moved through the Eaton configuration
  hardening epic (HAS-134) to **0.4.0** (2026-07-28) — unique `(point, gateway)` (HAS-138),
  400 for an unknown gateway (HAS-135) and request body validation (HAS-136). It is the
  **first migrated service that consumes the
  shared domain models**, so it is also the first consumer of `smart-home-sdk` (1.0.0 at the
  time of the migration, now 1.1.0; `cholewa-commons` 1.1.0 → now 1.2.0); the REST contract
  it serves to `amx-service` is unchanged, so
  `amx-service` keeps working on the old library versions. Two things surfaced there that
  every following service migration will hit: logbook 4.x needs the optional
  `spring-boot-http-client` module on Boot 4.1 or the context will not start, and the k8s
  manifest must launch the image with `-jar application.jar` — Boot 4 dropped `layertools`,
  so the old `JarLauncher` command crashes the pod (the `Dockerfile` needs
  `-Djarmode=tools ... extract --layers` for the same reason).
  The fourth service migrated is `water-service` — Java 21 / Spring Boot 4.1.0, released
  **0.2.0** (2026-07-29, HAS-127), deployed and verified on the cluster. It is the first
  migrated service using **both** shared model libraries (`smart-home-sdk` 1.1.0 and
  `shelly-client` 1.0.0, plus `cholewa-commons` 1.2.0) and the first to drop Eureka. Three
  things it added to the migration playbook: Boot 4.1 moved the `WebClient`
  auto-configuration out of `spring-boot-starter-webflux`, so a service building its own
  `WebClient` needs `spring-boot-starter-webclient` (otherwise there is no autoconfigured
  `WebClient.Builder` at all); the surefire `includes` added during a migration only match
  `**/*Test.java`, so a class named `...Tests` silently stops running; and the k8s manifest
  has to carry the `env` block with the database properties — `water-service` had none, and
  before the migration a broken `spring.flyway.url` default masked it. The fifth service
  migrated is `heating-service` — Java 21 / Spring Boot 4.1.0, released **1.1.0**
  (2026-07-30, HAS-123), deployed and verified on the cluster, and it is the **reference for
  every remaining service migration**: the first repo carrying the full target shape end to
  end — pom (Boot 4.1 / Java 21, `spring-boot-http-client`, `spring-boot-starter-webclient`,
  explicit `annotationProcessorPaths`), `Dockerfile` (`-Djarmode=tools ... extract --layers`,
  `EXPOSE 6200 8200`), SHA-pinned workflows with the Sonar quality gate, the `database.*`
  configuration group with `DatabaseProperties` instead of `spring.datasource.*`, and a k8s
  manifest with the launch command, resource limits, readiness/liveness probes and the
  RabbitMQ secret wired in. Use `water-service` only as the scaffold for **new** services.
  It added four more things to the playbook. Mockito 5.23 (managed by Boot 4.1.0) refuses to
  mock sealed types, so `Answers.RETURNS_SMART_NULLS` on a `java.time.Clock` mock now fails —
  the smart null for `getZone()` would be a mock of the sealed `ZoneId`. A `@RabbitListener`
  returning `Mono` needs `spring.rabbitmq.listener.simple.acknowledge-mode: manual`: with the
  default AUTO the container acks before the reactive pipeline runs, so prefetch throttles
  nothing and the ack is sent twice. A hand-built `ConnectionFactory` is **not** pooled —
  `R2dbcAutoConfiguration` backs off once such a bean exists — so it has to be wrapped in
  `io.r2dbc.pool.ConnectionPool` with a bounded `maxSize` and declared as
  `@Bean(destroyMethod = "dispose")`; the managed database allows 22 backend connections in
  total, split **heating 2 / database 4 / water 2 / presence 2 — 10 allotted, 12 free** since
  HAS-169 (2026-10-06; 4 / 6 / 4 / 2 before) for Flyway (a JDBC connection at every start),
  database tools, the low-traffic `reporter` database on the same cluster and services to
  come. The 22 is `max_connections` 25 minus 3 `superuser_reserved_connections`, read from
  `pg_settings`. **The split is sized for rollouts, not for the steady state**: the three
  Deployments keep the default RollingUpdate (owner's decision — no downtime, smaller pools
  instead of `Recreate`), so during a rollout the old and the new pod each hold a pool and
  Flyway adds one connection that no `r2dbc_pool_*` metric shows. One rollout is at most
  10 + 4 + 1 = 15, all three at once 21 — a margin, not an invitation: services with a
  database are still deployed one at a time. Raising any pool means re-doing that sum, and
  each service pins its size with a test (`*ApplicationTest`), because the library default
  of 4 no longer equals anyone's share but `database-service`'s. Three things HAS-169 taught:
  - **"Prefetch below the pool size" was a rule without a reason.** A `heating-service`
    message holds a connection only while its reading is saved and then spends its time in the
    Shelly calls, so the prefetch stays 3 over a pool of 2. A prefetch of 1 would have made
    the whole chain serial — one slow relay holding up the readings of every room. Check what
    an in-flight message actually holds before tying two numbers together.
  - **A timeout turns "slow" into "failed" — look at what the failure path cancels.** The
    Shelly `WebClient` of `heating-service` had no timeout at all; adding one (1.7.0) would
    have let one slow relay cancel the other actors of its room and skip the furnace flag and
    the floor pump, because the chain was fail-fast. Each actor now has its own
    `onErrorResume`, for device failures only (`boiler-service` learned the same in HAS-128).
    The timeouts are a validated properties record with a unit, a lower **and** an upper
    bound — "5000" meant as milliseconds would otherwise bind as 83 minutes.
  - **Measuring `pg_stat_activity` through the DataGrip MCP costs a connection per query**:
    every call opens a session that stays idle until the data source is deactivated — eight
    samples held eight of the 22 connections. Take one sample at the peak of a rollout (the
    new pod started, the old one still there), not a series.
  The SANCTUM room has a radiator `heating-service` must not drive: it is switched by a scene
  in the Shelly cloud, so the missing relay entry there is deliberate. The limit belongs to the **whole cluster, not to this
  project**: on 2026-10-03 the server ran out (`53300 remaining connection slots are
  reserved`) because an unrelated application held 10 connections next to pools sized for 21;
  its databases were removed from the cluster the same day, `presence-service` 0.3.1 went
  from 3 to 2 and `heating-service` 1.4.0 from 8 to 4 (it used 1-2; its RabbitMQ `prefetch`
  went 5 → 3 on the belief that the prefetch has to stay below the pool size — see HAS-169 above). `database-service` got its pool in
  HAS-163 (released 0.5.1) — the missing pool only became visible when Actuator arrived,
  because `ConnectionFactoryHealthIndicator` answered every `/actuator/health` call with a
  fresh physical connection; `r2dbc_pool_*` on `/actuator/prometheus` now makes the budget
  observable per service. **Since HAS-146 none of this is service code**: `cholewa-commons`
  1.3.0 ships `R2dbcConnectionFactoryAutoConfiguration`, which builds the pooled
  `ConnectionFactory` from the `database.*` group, and `heating-service` (1.3.2),
  `database-service` (0.5.2) and `water-service` (0.4.0) deleted their own `DbConfig` —
  `water-service` got its first pool that way. A service now pins only
  `database.pool.max-size`, its share of the budget; leaving it out silently drops the pool to
  the library default of 4. Two things the adoption costs. `@EnableR2dbcRepositories` has to
  be **dropped**, not moved onto the application class: `@WebFluxTest` bootstraps from the
  `@SpringBootConfiguration` class and applies its annotations, so the slice builds repository
  beans and dies on a missing `r2dbcEntityTemplate` that a web slice never auto-configures —
  Boot's `R2dbcRepositoriesAutoConfiguration` scans the right package on its own. And the
  library validates the connection properties at bind time, so a partially configured
  consumer now fails at startup naming the missing key instead of on the first query.
  **Since 1.5.0 the pool also validates every connection on acquire** (`SELECT 1`, bounded by
  `database.pool.max-validation-time`, default 2 s since 1.5.1, 5 s in 1.5.0) and caps its life
  (`max-life-time`, 30 min), plus TCP keepalive and a connect timeout on the driver. Recovery is
  **gradual**: a failed acquire discards up to two broken connections (r2dbc-pool retries once)
  and its caller may still get an error — the pool is clean after a few requests. Raising the
  retry count was tried and rejected, because r2dbc-pool retries every failure, pool exhaustion
  and an unreachable database included. Keep `max-validation-time` well below
  `max-acquire-time`, or the acquire limit cuts every validation off and nothing is discarded. The outage behind it (2026-09-26,
  HAS-150): the only pooled connection of `database-service` stopped getting answers; callers
  that timed out cancelled their queries, the cancel handed the connection back to the pool with
  the query still queued on it, every later caller queued behind it, and once the driver's
  request queue (256) was full every query failed instantly with `RequestQueueException` — for
  19.5 h, until the pod was restarted, while the pod stayed Ready. A connection used every 30 s
  never reaches `max-idle-time`, which is why neither idle eviction nor anything else noticed.
  The same outage added a 5 s timeout on `amx-service`'s call to `database-service` (1.2.1;
  since 1.2.2 a failed lookup answers the AMX controller with its real status — 404 unknown
  data point, 502 database-service failing or unreachable, 504 timeout — instead of a blanket
  400) and the Grafana rule `database-service not answering` (zero 2xx in 15 min) — `Error log
  spike` had only flapped, and the first 2.5 h logged no error at all.
  And a deployment that has fallen far
  behind can cross a rewritten Flyway migration — `heating-service` jumped from 0.2.1 (2024)
  to 1.1.0, where `V1` no longer creates the same table, so the legacy database refused
  validation; the fix was its own database (`home-automation-heating`), not `flyway repair`,
  which would have marked `V1` applied without creating the table.
  The sixth service migrated is `boiler-service` — Java 21 / Spring Boot 4.1.0, released
  **1.1.0** (2026-07-31, HAS-128), deployed and verified on the cluster (pod `1/1 Running`,
  zero restarts, so both crash-loop traps above were avoided). It followed
  `heating-service` as the reference and, like `water-service`, dropped Eureka; it is the
  second service in the cluster on the 6200/8200 port scheme with probes. Its image came
  out **smaller** than the Java 17 one (220 MB vs 225 MB) — removing the Spring Cloud BOM
  and the Eureka client more than paid for the newer base image. Two things it adds to the
  playbook. Excluding `org.apiguardian:apiguardian-api` from the logbook dependency (the
  copied-around template does this) makes javac emit `unknown enum constant
  org.apiguardian.api.API.Status` for every logbook class it reads, because logbook's
  classes carry `@API` annotations; the exclusion exists only because logbook 4.0.4 brings
  apiguardian 1.1.1 while JUnit 6 brings 1.1.2 and `dependencyConvergence` fails on that,
  so the fix is to drop the exclusion and pin the version in `dependencyManagement`
  instead. And when adding a `responseTimeout` to a `WebClient`, check what the timeout now
  aborts: in `boiler-service` the control pass was a fail-fast `then()` chain, so one slow
  relay reply cancelled the remaining devices — including the furnace, controlled last,
  which then kept burning until the next successful pass. Each step needs its own
  `onErrorResume`; that is safe there only because device state is written exclusively from
  actual device responses, so a skipped step cannot make the furnace fire on a pump that
  never confirmed it runs.
  The seventh and last service migrated is `amx-service` — Java 21 / Spring Boot 4.1.0,
  released **1.2.0** (2026-08-13, HAS-122), deployed and verified on the cluster. It is the
  first service that took the **whole observability package inside the migration**: the
  HAS-155 epic gave it no task, because the migration was still pending when the epic was
  planned, so metrics, JSON logs and tracing landed together with Boot 4.1 and the 6200/8200
  scheme (`heating-service` and `boiler-service` took only the ports and probes that way, and
  came back for the rest in HAS-160/161) — expect the same shape for `shelly-cloud-service`.
  Two beans it had to give up, both worth checking in every
  service that still builds its own: an own `WebClient.Builder` bean is **not** the
  autoconfigured one, so nothing instruments it and every outgoing call is untraced; and an
  own `RabbitTemplate` bean makes `RabbitAutoConfiguration` back off
  (`@ConditionalOnMissingBean(RabbitOperations.class)`), and since
  `spring.rabbitmq.template.*` is applied by `RabbitTemplateConfigurer` alone, both
  `observation-enabled` and the `retry` block are silently ignored — the published message
  carries no `traceparent` and the trace dies at the queue. `heating-service` never hit this
  only because it declares no template at all. Deleting the bean turns the dead retry
  settings on as a side effect, which is what they were written for.
  The eighth and last is `shelly-cloud-service` — Java 21 / Spring Boot 4.1.0, released
  **0.1.0** (2026-08-13, HAS-129), its first release and first deployment. It is a skeleton
  with no endpoints, so the migration could not break anything at runtime; the point was that
  the first feature starts on the target shape, observability included, like `amx-service`.
  Two things it turned up. Its repo had been scaffolded from `boiler-service` and never
  renamed, so `release.yml` pushed the image as `magikabdul/boiler-service` — a release from
  there would have overwritten the running boiler tags; check the image name, the Discord
  titles and the README whenever a repo starts as a copy. And its Spring Cloud BOM could not
  be bumped at all, only dropped, which is now the rule rather than the exception: no release
  train targets Boot 4.1. `api-gateway-service` followed as the eighth and last (HAS-170,
  released **0.1.0**, 2026-08-13), which makes **every repository in the organization**
  migrated. It is the one place where the missing release train could not simply be dropped —
  the gateway *is* Spring Cloud — so the BOM import is gone and
  `spring-cloud-starter-gateway-server-webflux` is pinned on its own — at 5.0.2 then, at
  **5.0.3** since gateway 0.3.0 (2026-10-05, HAS-152), which also moved it to Boot **4.1.1**.
  That pairing is an **accepted risk**: it works because Boot 4.1.x and the 4.0.x the 2025.1.x
  train is built against (4.0.8 for 5.0.3) share the Spring Framework 7.0.x line, it is
  verified by hand (context up, route proxies, unmatched path 404s), but it
  sits outside Spring's compatibility matrix — **re-test the gateway on every bump** of either
  version, and drop the pin the day a Boot 4.1 train ships. The re-test needs no cluster: start
  the jar with `home,local`, put any HTTP stub on a target's local port and call the route
  through `localhost:6200` (recipe in the gateway's `CLAUDE.md`).

## Conventions

- **Target toolchain: Java 21, Spring Boot 4.1.0** (`spring-boot-starter-parent`), Maven,
  groupId `cloud.cholewa`. New services and libraries start on the target versions.
  All four libraries are already migrated (`cholewa-commons` and `cholewa-security` on the
  target versions, `smart-home-sdk` and `shelly-client` on Java 21 without a Spring Boot
  parent; all first released as 1.0.0 — current latest: `cholewa-commons` **1.7.0**,
  `smart-home-sdk` **1.5.0**, `cholewa-security` and `shelly-client` still **1.0.0**),
  and **all nine services** — `notification-service`, `ai-service`, `database-service`,
  `water-service`, `heating-service`, `boiler-service`, `amx-service`,
  `shelly-cloud-service` and `presence-service` — plus `api-gateway-service` are on the
  target toolchain; nothing is left behind (the gateway pins its Spring Cloud starter by
  hand, see Pending architecture changes; `presence-service` was never migrated — it was
  scaffolded on the target versions in HAS-148).
- **Spring Boot follows the own-library rule (decided 2026-10-01, HAS-149)**: when a newer
  Boot release exists, the service being worked on moves to it in that task, together with
  the latest own libraries; the others follow with their next task — there is no org-wide
  bump. **Libraries with a Boot parent follow the same rule** (owner, 2026-10-05, HAS-180):
  `cholewa-commons` moved to 4.1.1 with 1.6.0, `cholewa-security` moves with its next task;
  `smart-home-sdk` and `shelly-client` have no Boot parent. A library built on 4.1.1 is fine
  for a consumer still on 4.1.0 — the consumer's own parent manages its versions. `presence-service` (since 0.2.0) is the first on **4.1.1**, `heating-service` (1.4.0)
  the second, `water-service` (0.5.0) the third, `api-gateway-service` (0.3.0) the fourth and
  `database-service` (0.7.0, HAS-145) the fifth, `notification-service` (0.3.0, HAS-94) the
  sixth, `amx-service` (1.3.0, HAS-176) the seventh, `boiler-service` (1.2.1, HAS-181) the
  eighth and `ai-service` (0.2.1, HAS-182) the ninth and `shelly-cloud-service` (0.1.1, HAS-183) the tenth
  and last. Every service is on 4.1.1 today; after the next Boot release a mixed fleet is again
  the expected state, not drift to report. With it came
  logbook **4.2.0** (built against Boot 4.1.1; 4.0.4 elsewhere) — verified on the cluster
  with `style: json` and header obfuscation. logbook 4.2.0 declares apiguardian 1.1.2 itself,
  so the `apiguardian-api` pin in `dependencyManagement` goes with the bump (dropped in
  `heating-service`, `water-service`, `api-gateway-service`, `database-service`, `amx-service`,
  `notification-service`, `boiler-service`, `ai-service` and `shelly-cloud-service`;
  `presence-service` still
  carries it, harmlessly). The one place where a Boot bump is not routine
  is `api-gateway-service`, whose hand-pinned Spring Cloud starter has to be re-tested.
- **A reactive `@Scheduled` method is called once, not once per run** (found in HAS-154). Spring
  invokes a method returning a `Mono` at startup, keeps the publisher and **subscribes to it
  again** for every run (`ScheduledAnnotationReactiveSupport`). Whatever is computed while the
  `Mono` is built — "now", a cutoff, anything read from mutable state — is frozen at the start
  of the pod. The retention job of `presence-service` first computed its cutoff that way: it
  would have deleted up to the same date every night until a restart, and logged that date as
  if it were current. Everything that depends on time or state belongs inside the chain
  (`Mono.defer`, or a lambda of an operator), and the test for it has to subscribe **twice to
  the same `Mono`** with the clock moved on — a fresh call per test cannot see the bug.
  Checked on 2026-10-05: `water-service` (`WaterSensorCron`) and `boiler-service`
  (`StatusCron`) are clean, everything there happens in operator lambdas.
- **Error messages are English, always** (owner's rule, 2026-10-05, HAS-145) — in responses
  and logs, on every machine. The one source that breaks it silently is Bean Validation: a
  violated constraint is worded in the locale of the JVM or the request, so the same request
  reads in Polish on a developer machine and in English in the cluster (the pods run
  `en_US`). `database-service` (0.7.0) pinned it first, with a `ValidationMessagesConfig` of
  its own — a `ValidationConfigurationCustomizer` replacing the message interpolator with one
  that ignores the locale; it has to be a customizer, because Spring installs its own
  locale-aware interpolator and runs the customizers after it. **Since `cholewa-commons` 1.6.0
  (HAS-180) the library does it for every consumer**: `ValidationMessagesAutoConfiguration`,
  on by default, switched off with `cholewa.validation.english-messages: false`. A service
  taking 1.6.0 or later needs no code, and `database-service` deleted its local copy with the
  bump (0.8.0, HAS-175) — it ran after the library's and put back the older variant. What a
  consumer keeps is a test: the whole context on a Polish JVM expecting English, plus a
  control with the property switched off — a `@SpringBootTest`, because a `@WebFluxTest`
  slice does not load the library's auto-configuration.
  A locale-dependent text is a defect to fix, not a caveat to document — with **one accepted
  exception** (owner, 2026-10-05): the validation of `@ConfigurationProperties` at startup
  still follows the JVM locale, because Boot builds a validator of its own there and the only
  lever, a global `LocaleContextHolder` default, would change locale resolution for the whole
  application. It concerns the log of a failed start only, never a response. Three things the
  library version had to get right, worth knowing before writing anything similar:
  - Wrap the interpolator Boot builds (`new MessageInterpolatorFactory(applicationContext)`),
    not `configuration.getDefaultMessageInterpolator()`: the latter drops the `MessageSource`
    lookup — a `{key}` from `messages.properties` comes out as the literal key — and the
    fallback for an application without an Expression Language implementation.
  - Pin `Locale.ROOT`, not `Locale.ENGLISH`: asked for `en`, a bundle lookup that finds no
    `_en` file falls back to the JVM default *before* the root, so a `_pl` file wins on a
    Polish machine. Hibernate's own messages hide this, because it ships an empty
    `ValidationMessages_en.properties`. A test with built-in constraints alone cannot see it;
    it takes bundles with a `_pl` file and no `_en`.
  - A customizer bean in a library needs a name no consumer already uses and an explicit
    order: same name → the consumer's context fails on a bean-definition override; no order
    → the library's customizer runs last and overwrites the consumer's.
- **Errors between services carry a code, and a decoded error keeps its status** (epic
  HAS-172; the library part is `cholewa-commons` 1.7.0, HAS-174). `ErrorMessage` has an
  optional `code` — the **name** of an `ErrorId` constant (`ErrorId.codeOf(...)`), absent from
  the JSON unless a processor sets it — so a caller can tell causes apart without parsing
  text: a routing 404 and "no such record" are both a 404, and only the second carries a
  code. `DownstreamErrors.read(ClientResponse)` returns the status of an error response
  together with its messages (`Errors.httpStatus` is `@JsonIgnore`, so a decoded body never
  knows its own status) and `hasCode(...)` asks for a cause. Rules that come with it:
  - **The name of an `ErrorId` constant is wire contract** once a caller branches on it.
    Renaming it compiles and passes every test of its own service, and silently changes what
    the caller does. The service owning the enum pins the names with a test.
  - **Only named causes travel past the first hop, and never their `details`.** The built-in
    `WebClientResponseExceptionProcessor` relays a downstream message only when it carries a
    code, as `message` + `code`. `details` is by convention the raw exception text; relayed,
    a downstream 500's SQL would reach a caller two hops away, from services the gateway does
    not route. No org service reaches that processor today — every client maps its errors to
    an exception of its own.
  - **A helper that promises "the status is never lost" has to survive every body**: none,
    HTML, JSON of another shape, `"errors":[null]`, a rewritten `Content-Type`, a body that
    breaks off and one that never ends. Four review passes found one of these each time; the
    library version reads the body as text, parses it itself, bounds the wait (2 s, below the
    caller's own call timeout) and has a test per case.
  - `database-service` **sends the codes since 0.8.0** (2026-10-06, HAS-175): one
    `DomainExceptionProcessor(status, ErrorId)` instead of a processor class per exception,
    the names of `CustomErrorDescription` pinned by a test, and the codes listed in its
    README. Bodies changed only by the added `code`; `amx-service` 1.2.2, then on
    `cholewa-commons` 1.5.1, read them unchanged (verified on the cluster).
  - `amx-service` **reads the code since 1.3.0** (2026-10-06, HAS-176): its 404 from
    `database-service` is relayed to the AMX controller only with
    `NOT_FOUND_DEVICE_CONFIGURATION`; a 404 without it — a renamed path, a broken route — is a
    502 logged at ERROR, where it used to pass as an unknown data point at WARN. So
    `amx-service` ≥ 1.3.0 must never run next to a `database-service` below 0.8.0: every
    unknown data point would read as a 502. The review added three things worth copying into
    every client of another service: a 502 answers with the downstream status alone and what
    the failing service said goes to the log (the exception carries the two sets apart); an
    answer without a body, or JSON that is not the model (`{}` decodes into an object of
    nulls, `@NotNull` is not enforced on decode), is a failed call, not an empty result; and
    the test of such a rule asserts the **log level**, because the level is what the alerts see.
- **A constraint on a query parameter or path variable needs no `@Validated`** (HAS-145).
  Since Spring Framework 6.1 WebFlux validates a constrained `@RequestParam` /
  `@PathVariable` itself and raises `HandlerMethodValidationException`. `@Validated` on the
  controller class switches that **off** in favour of an AOP proxy answering
  `ConstraintViolationException`: every `@Valid` body is then validated twice, and the
  `cholewa-commons` processor puts the Java method name into the answer
  (`getEatonDeviceConfiguration.point: …`). The built-in exception, in turn, is answered by
  the `cholewa-commons` default as a bare "Validation failure" — `database-service` adds
  `InvalidRequestParameterProcessor`, which lists the violated constraints' messages; a
  candidate for the library once a second service needs it.
- **A `Duration` property without a unit binds as milliseconds.** `PRESENCE_RETENTION=365`,
  meant as days, would have put the retention cutoff at "now" and let the nightly job delete
  the whole table. A duration that decides what gets deleted (or how long something waits)
  carries `@DurationUnit` and a lower bound (`@DurationMin`), and a context-runner test pins
  both — as in `PresenceProperties`.
- **A repository test without PostgreSQL**: `presence-service` runs one statement — its
  retention `DELETE` — in a `@DataR2dbcTest` slice on an in-memory H2 (`r2dbc-h2`, test
  scope). The slice does not load the pooled `ConnectionFactory` of `cholewa-commons`, so
  `spring.r2dbc.url` alone points it at H2; the table is created by the test (no Flyway in
  the slice), and H2 needs `CASE_INSENSITIVE_IDENTIFIERS=TRUE`, because Spring Data quotes
  the table name while raw `@Query` SQL does not. Good for portable, destructive statements;
  PostgreSQL-only SQL (`DISTINCT ON`) would take Testcontainers.
- **Calling a device or gateway outside the cluster** — what `presence-service` learned on
  the UniFi gateway (HAS-149), worth checking in every client of an external system:
  - A self-signed certificate is **pinned by fingerprint**
    (`FingerprintTrustManagerFactory`, fingerprint in `application.yaml` — it is not a
    secret), never accepted with `InsecureTrustManagerFactory`. When the certificate does
    not name the address it is reached by, hostname verification has to go, and that takes
    `setEndpointIdentificationAlgorithm("")`: the JDK ignores `null` and keeps verifying,
    which shows only against a real HTTPS endpoint — so the pinning gets its own test on an
    HTTPS `MockWebServer` (`okhttp-tls`), in both directions.
  - `WebClientRequestException` covers failures only **up to the response headers**. A
    stall or a dropped connection in the middle of the body arrives as
    `WebClientResponseException`, a wrong payload as `DecodingException`, and a 200 with
    valid JSON but no payload as a `NullPointerException` further down the chain. An error
    mapping that promises "every failure becomes our exception" has to map everything and
    sit after the null check; `headersDelay` alone does not test it, `bodyDelay` and
    `onResponseBody(new SocketEffect.CloseSocket())` do.
  - A property with a harmless-looking default (`host: localhost`) defeats `@NotBlank`: the
    pod starts, turns Ready and fails every call. Mandatory connection settings get no
    default outside the `test` document.
  - The wire model and the service's own model must not be interchangeable by accident —
    two records with the same field names compile when swapped, and the validation in the
    domain constructor then fails inside Jackson, before any filter runs.
  - Tests use `com.squareup.okhttp3:mockwebserver3`, not the legacy `mockwebserver`, which
    drags JUnit 4 onto the classpath (a JUnit 4 test compiles, never runs, build stays
    green). The trap is still in heating- and water-service
    from the shared scaffold; `boiler-service` left it in 1.2.1 (HAS-181) and
    `shelly-cloud-service` in 0.1.1 (HAS-183).
- **A `@SpringBootTest` context schedules whatever the application schedules** (found in
  HAS-181). The context test of `boiler-service` started the control pass with the real Shelly
  address, and only the test JVM ending within the 10 s initial delay kept it from switching
  the relays in the boiler room. Since 1.2.1 `@EnableScheduling` sits on a `SchedulingConfig`
  under `@Profile("!test")`, the `test` document points the device at `localhost:1`, and the
  context test carries `@ActiveProfiles("test")` itself — the profile surefire sets does not
  exist when the class is started from an IDE. Worth checking in every service whose
  scheduled job writes to a device, a database or a queue. For the same reason a **local run of
  `boiler-service` drives the real relays**: no profile but `test` moves the Shelly address.
- **Ports**: in the cluster every service listens on **6200** (application) and exposes
  Actuator on **8200** (`management.server.port` in the `home` profile) — the k8s ingress
  routes only 6200, so Actuator is unreachable from outside; `readinessProbe` /
  `livenessProbe` in the manifest target 8200 (`/actuator/health/{readiness,liveness}`),
  and the `Dockerfile` declares `EXPOSE 6200 8200`. Locally each service keeps its own pair
  from the table above: **600x** for the application and **800x** for Actuator, set in the
  `local` profile. `heating-service` (HAS-123, released 1.1.0) is the first service running
  on this scheme in the cluster and the first with probes — it also pins
  `management.endpoint.health.probes.enabled: true` instead of relying on Boot detecting the
  Kubernetes platform, because a 404 on the readiness path would crash-loop the pod;
  `boiler-service` (HAS-128, released 1.1.0) is the second, `water-service` (HAS-162,
  released 0.3.0) the third, `database-service` (HAS-163, released 0.5.0) the fourth and
  `notification-service` (HAS-164, released 0.2.0) the fifth, `ai-service` (HAS-165,
  released 0.2.0) the sixth and `amx-service` (HAS-122, released 1.2.0) the seventh — none of
  those five had an Actuator at all until its
  observability task, which is why their manifests carried the probes commented out
  (`amx-service` also had a stray `EXPOSE 6200 9200` matching no scheme). With
  `amx-service` — and `shelly-cloud-service` (HAS-129), which was born on it — every service
  in the `smart-home` namespace is on the scheme; only
  nothing is left outside it — `api-gateway-service` joined in HAS-170. Note that this pin
  belongs in
  the shared (default) document of `application.yaml`, not in the `home` section — kept
  there, the probe paths can be exercised locally on 80xx before the manifest ever reaches
  the cluster. The
  others still set `management.server.port` only in the `local` profile — in the cluster
  their Actuator shares 6200 and their manifests have no probes. They adopt the scheme
  during their own Java 21 migration, or during their observability task when the migration
  is already behind them.
- **Observability** (epic HAS-155, Grafana stack): every service exposes
  `health,info,prometheus` on the management port and carries the
  `prometheus.io/scrape|port|path` annotations on its Deployment pod template — Prometheus
  discovers pods by annotation, so nothing on the Prometheus side changes per service.
  Dashboards are provisioned from ConfigMaps in `deployment-tools`
  (`k8s/monitoring/grafana/dashboards/`, HAS-166) — the service identity label there is
  **`app`** (relabelled from the pod label `name`), not the Micrometer `application` tag,
  which no service sets; in Loki it is `app` as well, and the logs parse with `| json`.
  A community dashboard assuming other names renders empty panels rather than failing.
  Cluster logs are JSON via `logging.structured.format.console: logstash`. That property
  belongs in the **shared** document with an empty-value override in `local`, not in a
  `home`-only document: locally the services run with `home,local` together, so a `home`
  document would apply there as well. Boot installs the structured encoder only when the
  value has length (`DefaultLogbackConfiguration.createEncoder`), so `console: ""` in the
  `local` document restores plain text. The **`test` document needs the same override**, and
  surefire has to activate that profile for every class
  (`<systemPropertyVariables><spring.profiles.active>test</...>`): a test class without
  `@ActiveProfiles` falls through to the shared document and logs JSON, and because surefire
  reuses a JVM across classes, one such context installs the structured encoder for the plain
  unit tests that follow — which is why the output looks randomly mixed. `@ActiveProfiles`
  still wins over the system property (they do not merge), so a test can opt into another
  profile. Done in `heating-service`, `database-service` and `water-service` (HAS-146) and in
  `notification-service` (HAS-94), in `boiler-service` (HAS-181), `ai-service` (HAS-182) and
  `shelly-cloud-service` (HAS-183) —
  there the context-starting test classes also carry `@ActiveProfiles("test")`, because the
  surefire property does not exist when a class is started from an IDE; the
  other services still have the split. `heating-service` (HAS-160, released 1.2.0) is the
  first service on this scheme, `boiler-service` (HAS-161, released 1.2.0) the second,
  `water-service` (HAS-162, released 0.3.0) the third, `database-service` (HAS-163,
  released 0.5.0) the fourth, `notification-service` (HAS-164, released 0.2.0) the fifth,
  `ai-service` (HAS-165, released 0.2.0) the sixth, `amx-service` (HAS-122, released
  1.2.0) the seventh and `shelly-cloud-service` (HAS-129, released 0.1.0) the eighth and
  last — the last two outside the epic, inside their Java 21 migrations;
  note that `micrometer-registry-prometheus` was already on the heating classpath, while the
  others have to add it — and for `water-service`, `database-service`,
  `notification-service`, `ai-service` and `amx-service` the missing piece was
  `spring-boot-starter-actuator` itself (the last four had the registry in their poms all
  along, dead without the starter), so for a service without Actuator the task also brings
  the 6200/8200 scheme and the probes. One thing `ai-service` added: switching the cluster
  logs to JSON turns anything a service echoes from an upstream error into stored, searchable
  text — there the OpenAI error message quotes the rejected API key back, so the provider
  failure is now mapped to a fixed 502 message and only the exception type is logged. Worth
  a look wherever `DefaultExceptionProcessor` still passes an upstream message through as
  `details`.
- **Request tracing**: Micrometer Tracing with the Brave bridge
  (`spring-boot-micrometer-tracing-brave` + `io.micrometer:micrometer-tracing-bridge-brave`),
  **without any exporter** — no Tempo or Zipkin in the stack. The trace lives in the logs:
  `traceId` / `spanId` land in the MDC, and Boot's logstash formatter writes the whole MDC
  map as top-level JSON fields (`LogstashStructuredLogFormatter` — `pairs.addMapEntries`),
  so one request is followed across services with
  `{namespace="smart-home"} | json | traceId = "…"`. Three settings this needs, all of them
  non-obvious defaults: `spring.reactor.context-propagation: auto` (the default `LIMITED`
  restores ThreadLocals only in `tap` and `handle`, so a log statement inside a reactive
  chain has no `traceId`), `spring.rabbitmq.template.observation-enabled` **and**
  `spring.rabbitmq.listener.simple.observation-enabled` (both default `false` — without them
  the trace breaks at the queue), and `management.tracing.sampling.probability: 1.0` (default
  0.1; the traffic is tiny and a partial trace is worthless when logs are the only record).
  A `WebClient` must be built from the injected `WebClient.Builder` or it is not
  instrumented. `heating-service` is the first service with tracing, `boiler-service` the
  second, `water-service` the third, `database-service` the fourth — that one is mostly
  the receiving end, so a caller's `traceId` now continues into the persistence logs instead
  of stopping at the REST boundary — and `notification-service` the fifth, the first
  RabbitMQ **consumer** of the epic, where the `.contextCapture()` fix below was needed for
  real (`acknowledge-mode` was not: `AbstractMessageListenerContainer` forces MANUAL by
  itself for a listener returning an async reply, so only `heating-service`, which also
  wanted prefetch throttling, sets it explicitly) — and `ai-service` the sixth, where the
  `ChatClient` built from the injected `ChatClient.Builder` puts Spring AI's own observations
  under the trace of the request that triggered the call, and `amx-service` (HAS-122) the
  seventh, the first RabbitMQ **producer** of the chain: the AMX datagram, the lookup in
  `database-service` and the consumption in `heating-service` now share one `traceId`, which
  is what made the `RabbitTemplate` trap above visible, and `shelly-cloud-service` (HAS-129)
  the eighth, which was scaffolded with it rather than retrofitted, and `api-gateway-service`
  (HAS-170) the ninth and last — the one that matters most, since it opens the trace every
  external request is then followed by. One limit to know there: logbook's own lines never
  carry `traceId`, so for plain proxied traffic the gateway contributes the id but no log line
  of its own. Every service now traces
  — **tracing is part of the observability task, not a separate one**.
  A `@Scheduled` method needs nothing extra: Spring opens an observation around the task and
  writes it into the reactor context before subscribing
  (`ScheduledAnnotationReactiveSupport$SubscribingRunnable`), so a whole scheduled pass
  shares one `traceId` — verified in `boiler-service`, where the status loop, both service
  calls and every device command land under the same id and the `traceparent` header carries
  it into `heating-service`, and again in `water-service`, where the sensor read and the
  database write share one.
  One trap costs a whole trace and was diagnosed the hard way in `heating-service`: a
  `@RabbitListener` returning `Mono` keeps `traceId` only on the container thread. At
  subscribe the listener observation is on the thread and the MDC is set, but the reactor
  context is empty (`hasObservationKey=false, keys=[]`) — Spring AMQP subscribes in a way
  that does not trigger the automatic ThreadLocal capture and, unlike the HTTP path, never
  writes the observation into the context itself (`HttpWebHandlerAdapter:401` does, which is
  why controllers need nothing). Everything the message triggers is then logged without a
  `traceId`. The fix is `.contextCapture()` as the last operator of the listener chain.
  Logbook's own lines never carry `traceId` regardless — the netty handler writes outside the
  reactor chain, so that would need a custom `HttpLogWriter`.
- **Logging volume — conscious decision (2026-08)**: logbook stays at
  `logging.level.org.zalando.logbook: trace` in the cluster with full request and response
  bodies. Full information is worth more than the storage, so **do not propose trimming it
  in reviews**. Should it ever need trimming, the level is the wrong knob —
  `DefaultHttpLogWriter` logs at TRACE and its `isActive()` checks `isTraceEnabled()`, so
  `info` disables logbook completely. Use logbook's own settings instead:
  `logbook.strategy: body-only-if-status-at-least` (keeps a line per request/response, bodies
  only for errors; other values are `status-at-least` and `without-body`),
  `logbook.write.max-body-size` and `logbook.exclude`. The known risk of the current setting:
  the CRI runtime splits log lines at 16 KB, and a split line stops parsing under Loki's
  `| json`.
  Logbook's own JSON ends up escaped inside the `message` field, because two JSON layers are
  stacked — read it in Grafana with a re-parse:
  `… | json | line_format "{{.message}}" | json`. Getting rid of the escaping for good would
  mean dropping Boot's native structured logging for `net.logstash.logback` plus
  `org.zalando:logbook-logstash` (which also drags `jackson-databind` back in) — deliberately
  not done.
- Libraries are consumed from GitHub Packages: org libraries from
  `maven.pkg.github.com/smart-home-automation-system/*`, the personal-account libraries
  (`cholewa-commons`, `cholewa-security`) from `maven.pkg.github.com/magikabdul/*` —
  see the note under the library table.
- CI/CD — GitHub Actions in every repo:
  - `CI.yml` — build + tests on push/PR.
  - `sonar.yml` — SonarCloud analysis.
  - Services: `release.yml` — release builds a Docker image pushed to Docker Hub.
  - Libraries: `package.yml` — release publishes the artifact to GitHub Packages.
- A new microservice mirrors the structure and workflows of `water-service`
  (the reference service — since HAS-127 it is itself on the target toolchain, so its pom,
  `Dockerfile` and workflows can be copied as they are) — use the `new-service` skill from
  the `smart-home` plugin (`claude-tooling` repo); for libraries, `new-library` with
  `smart-home-sdk` as the reference.

## Working rules for Claude

- **Spring Boot services and libraries**: the user writes the code themselves. Do NOT write
  or modify code there unless explicitly asked. Default contributions: analysis, code
  review, security review, answering questions.
- **`web-application`**: full autonomy — Claude designs and implements the frontend.
- **`amx`**: NetLinx language; analysis and suggestions, ask before modifying.
- Never commit or push unless explicitly asked.
- **All changes to Spring services, libraries and `web-application` go through pull
  requests** — no direct commits to `main`. Branch naming: **`feature/HAS-<n>`**, where
  `<n>` is the Jira task number (HAS project). When no Jira task covers the change,
  create one first (`jira-backlog`) or confirm with the user how to proceed.
  - **No merge without both reviews.** Before a PR of a service or library is called ready
    for merge, Claude runs **`service-review` and `/code-review`** on its diff, shows the
    results and records the outcome on the PR. Until both are done: no merge, so no release
    and no deploy — Claude does not hand over a `gh release create` command for an
    unreviewed change. This holds for small follow-up PRs too (test fixes, version bumps).
    (HAS-150 shipped seven PRs across four repos with neither review; the quality gate found
    it only after release and deploy.)
  - **Exceptions — commit straight to `main`, no branch or PR:** `organization-repository`
    (this `.github` repo), `deployment-tools` and `claude-tooling`. Do not create
    `feature/*` branches or PRs for these; just commit to `main` and push (still only when
    explicitly asked). They also do not need a Jira task of their own — a change there is
    usually a side effect of work tracked elsewhere, so reference that task in the commit
    message when one exists.
- All repos except `deployment-tools` are public: never put secrets, tokens, IP addresses,
  or private infrastructure details into files of public repos.
  - Accepted risk (conscious decision, 2026-07): private **LAN IPs** already present in
    service configs (e.g. `application.yaml`) are tolerated — keeping them beats the
    overhead of maintaining k8s secrets for LAN addresses. Do not flag them in reviews.
    Secrets, tokens and credentials remain strictly forbidden.
