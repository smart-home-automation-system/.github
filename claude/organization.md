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
| `api-gateway-service` | 6200 | Spring Cloud Gateway — the **only** entry point into the cluster from outside; static routes to the services over k8s DNS (see External traffic) | **0.8.0** (2026-10-19, HAS-265) |
| `amx-service` | 6001 | Bridge to the AMX control system over **one permanent TCP socket to the frame server of the Television master** (port 20010, NetLinx side HAS-230): receives every Eaton frame of both gateways and publishes the readings, **sends** Eaton frames (blinds, lights, levels) the other way; publishes what an Eaton blinds, light, dimmer, push button or PIR sensor reports as `DeviceEvent` to `/device` (HAS-229, HAS-288); `POST /home/amx` is gone since 2.0.0 (HAS-286); asks a blinds actuator (`0B`, `POST /home/amx/eaton/blinds/{point}/status`, HAS-291) or a light actuator (`.../lights/{point}/status`, HAS-259) for its status; tells the household when the frame server is not connected for 5 min (an alert, hourly reminders, an info on the return - HAS-309) | **2.5.0** (2026-10-23, HAS-309) |
| `heating-service` | 6002 | Heating control; watches the temperature sensors (an alert after 24 h of silence); serves the rooms, the floor pump and the stored temperature history read-only — the contract of the dashboard. Open windows (HAS-232): the opening sensors of a room from the registry and the BTHome gateways (a copy of `WindowSensors` of blinds-service, per room), the `bthomesensor` topics of `device.prod.heating` over a third connection to `/device` (`device-rabbitmq-password`); a window or door open for `heating.window.hold-after` (**PT3M**) holds every heater of the room (checked every minute too), an unknown sensor never holds and a silent one is an alert; `GET /rooms` answers `window` (`state` as in blinds, `openSince`, `hold`). Its Logbook lines carry the `traceId` since 1.11.0 (HAS-298, the first consumer of `cholewa-commons` 1.10.0; its own `LogbookClientHandler` are gone; 1.11.1 - the actuator out of the log) | **1.11.2** (2026-10-22, HAS-303: every scheduled task bounded, the scheduler pool of cholewa-commons 1.11.0) |
| `notification-service` | 6003 | Consumes the `alert` and `info` queues and posts each message to the Discord channel `alerts` as an embed coloured by its level — two listener containers on purpose (HAS-179) | **0.4.4** |
| `ai-service` | 6004 | AI integration (Spring AI 2.0 `ChatClient`, OpenAI) | **0.2.1** |
| `database-service` | 6005 | Persistence facade: the household registry (members, devices, roles, rooms, permissions; the profiles of the dashboard), the **device registry** of every device of the house (read and written; the Eaton configuration `amx-service` asks for is served from it) and the **calendar of the house** (days off); since 0.16.0 the `openingSensors` of blinds (V16, each a registered opening sensor; a sensor in use is not removed - `DEVICE_CONFLICT`); since 0.17.0 a `presence sensor` may have a zone (200-299, `presencezone:200`) as its Shelly channel (V17) | **0.17.0** (2026-10-19, HAS-260) |
| `water-service` | 6006 | Hot water: reads a Shelly Uni every 3 min, keeps the flag `boiler-service` polls (on below 38 °C, off above 42), serves the dated reading and the stored history | **0.6.0** |
| `boiler-service` | 6007 | Drives the furnace and both pumps as relays of one Shelly Pro 4; alerts when that Shelly stops answering (HAS-109) | **1.4.0** (2026-10-23, HAS-306: the control pass bounded at 3 min, cholewa-commons 1.11.0) |
| `shelly-cloud-service` | 6008 | Shelly cloud integration — a **skeleton** (Actuator only, no endpoints) | **0.1.1** |
| `presence-service` | 6009 | Household presence: UniFi clients matched against the household registry every minute, status changes stored, four routed reports, nightly retention (`P365D`). State in the memory of one instance: `Recreate`, never scaled | **0.6.0** |
| `weather-service` | 6010 | The weather station (epic HAS-233): a Shelly WS90 read locally through a BTHome gateway, the readings kept and served to the dashboard, the blinds schedules and the overview. The station is adopted by the Plug S Gen3 TREADMILL (HAS-234; registry: gateway 54, station 55). Takes in the readings (HAS-236): the station and its gateway from the registry, which `bthomesensor` is which metric from the gateway (`Shelly.GetComponents`), the current state in memory from the status topics (13 metrics, each published only on a change) and from the read of the gateway, a snapshot a minute into `weather_reading` of its own database `home-automation-weather` (after a change only). Reconciles with the gateway every 5 min and watches it (HAS-237): no reading from the station or no answer from the gateway for 30 min is an alert, a reminder every hour, one info when over; open alerts in `station_alert`. Read API (HAS-238): `GET /home/weather/current` (per metric value, measuredAt, stale), `/status` (gateway reachable, last reading, silent), `/history?metric=&from=&to=` (the rules of the hot-water history, avg/min/max, `UNKNOWN_METRIC`); readings kept 730 days. `Recreate`, never scaled. Routed as a GET allowlist (gateway 0.6.0, HAS-239) | **0.4.1** (2026-10-23, HAS-304: every scheduled task bounded, cholewa-commons 1.11.0) |
| `blinds-service` | 6011 | Roller shutters (epic HAS-242): Eaton blinds through `amx-service`, Shelly blinds, the real state, weather-aware schedules. Knows the blinds from the device registry (every 5 min) and moves them on command through three drivers - Shelly Gen1 roller, Shelly Gen2 cover, Eaton through `amx-service` (HAS-244); `POST /home/blinds/{id}`, `/{id}/position`, `/rooms/{room}`. Tracks the real state of every blind (HAS-245): Gen2 covers from `device.prod.blinds` (MQTT) plus `Cover.GetStatus` every 5 min, Gen1 rollers by `/status` every 60 s and their `roller_*_url` actions on `GET /home/blinds/events/gen1` (open / close when a roller starts, stop when it stops - then `/status` is read; 0.8.1, configured on the eight rollers in HAS-255), Eaton from the `status` events of `amx-service`; table `blinds_state`; `GET /home/blinds`, `/rooms/{room}`, `/{id}`. Stores the schedules (HAS-246): CRUD under `/schedules`, `INVALID_SCHEDULE` / `NOT_FOUND_SCHEDULE` (texts for the dashboard, HAS-253). Confirms an Eaton move with a status request when its start is not reported (HAS-291). Runs them (HAS-247): every minute from the calendar of `database-service`, the sun (`location-latitude` / `-longitude` of the manifest) and `GET /home/weather/current` (an unknown input never holds), once a window per schedule and blind (`blinds_schedule_run`); `GET /schedules/{id}/today`. Window sensors per blind (HAS-290): the BLU Door/Window sensors linked by `openingSensors`, read from the registered `bthome gateway` devices (`Shelly.GetComponents` every 5 min, `bthomesensor` status topics between); a BLU sensor has no heartbeat, so a state holds while its gateway confirms it (`blinds.window.gateway-silent-after`, PT30M); `window closed` is judged per blind with its own hold; `GET /home/blinds` and `/today` show the window (`closed`, `open`, `no sensor`, `unknown`); a schedule window may cross midnight and belongs to the day it opened on. The pause of the schedules of one blind (HAS-232, supersedes HAS-248): `PUT` / `DELETE /home/blinds/{id}/schedule-pause`, ends by itself with the next run it prevents (stored as `PAUSED`, V4); `GET /home/blinds/{id}/schedules` (today, per blind); `schedulePausedSince` in the reads. Routed by path, every method (gateway 0.7.0, HAS-251). A condition `lt` at the least of its range or `gt` at the most is refused - never true for the strict comparison (HAS-294, `illuminance lt 0`). Every command waits for the report that answers it (HAS-250, 60 s for a Gen2+ cover, 2 min for Gen1 and Eaton): unanswered is `lastCommandConfirmed: false` in the reads, the third in a row an alert; a Shelly blind unreachable for 5 min is an alert, reminded hourly, an info on its return (open alerts in `blinds_availability_alert`, V5; Eaton not watched). Own database, `Recreate`, never scaled | **0.10.1** (2026-10-22, HAS-301: every scheduled task bounded, the scheduler pool of cholewa-commons 1.11.0) |
| `light-service` | 6012 | Lights (epic HAS-256): Eaton lights through `amx-service`, Shelly lights, the real state, room rules driven by motion and presence, the empty house. Consumes `device.prod.light` on `/device` (HAS-257); knows the lights from the device registry (every 5 min, a light without `lightKind` skipped) and switches them through three drivers (HAS-258) - Shelly Gen1 `/relay`, `/light`, `/color`, Gen2 `Switch`, `Light`, `RGB` or `RGBW.Set` by the profile of the device, Eaton through `amx-service`; `POST /home/light/{id}?turn=`, `/{id}/brightness`, `/{id}/color`, `/rooms/{room}`; `NOT_FOUND_LIGHT`, `UNSUPPORTED_CAPABILITY`, `DEVICE_FAILED`, `REGISTRY_UNAVAILABLE`. Tracks the real state of every light (HAS-259) - Gen2 MQTT and `GetStatus` every 5 min, Gen1 `/status` every 60 s and `GET /home/light/events/gen1` (actions configured with HAS-265), Eaton status events and a status request of every Eaton light at the start; `light_state` (V1); `GET /home/light`, `/rooms/{room}`, `/{id}` - a field not known is left out. Occupancy (HAS-260): the presence sensors (Presence Gen4 by its zone, registry 91-93), the BLU Motion through the BTHome gateways, the Shelly Motion Gen1 by its actions and the Eaton PIR - occupied / empty / unknown per room, `lastMotionAt`, `illumination`, `lux`, in memory (unknown after a start); `GET /home/light/rooms/{room}/occupancy` and the same object in the room reads. Routed by path, every method (gateway 0.8.0, HAS-265); the Shelly Motion of the sanctum (103) calls `/events/gen1` through it. The rules of a room (HAS-261): `light_room_rule` and `light_motion_period` (V2) - auto-off, motion-on with periods per time of day, a lux gate, a manual hold, the switch of the resident (kept by a write of the administrator); `GET /home/light/rules`, `GET` / `PUT` / `DELETE /rooms/{room}/rules`, `PUT /rooms/{room}/rules/resident-enabled`; `INVALID_RULE` with the reason (a room on Eaton PIRs only gets no rule), `NOT_FOUND_RULE`. The engine (HAS-262): auto-off, motion-on, motion-off and the manual hold, at every fresh motion and every minute, commands with `source=rule`; the hold is derived from the state (a change not of `rule` / `empty-house` holds `manualHoldMinutes`), `heldUntil` in the light reads; every command logged in `light_rule_run` (V3), `GET /rooms/{room}/rules/runs?from=&to=` (at most 7 days). The empty house (HAS-263): presence-service every minute (unknown is never empty), the room rules pause while nobody is at home; by day the lights left on are switched off, by night (civil dusk to sunrise, `location-latitude` / `-longitude` of the manifest) a presence simulation from a stored plan (`GET` / `PUT /empty-house/plan`, V4, `INVALID_PLAN`) - phases evening / night / morning, seeded by the date, never against a light a person switched after the house emptied; `GET /empty-house`. The availability monitor (HAS-264): a Shelly light unreachable for 5 min, a presence sensor silent for 30 min, a battery motion sensor for 24 h - one alert a pass naming every device, a reminder every hour, an info on return (a light only once it answers again - HAS-296); open alerts in `light_availability_alert` (V5); Eaton lights and AMX PIRs not watched. An Eaton command whose status is not reported within 5 s is confirmed by a status request; a command of the rules the light did not take is sent once more, never a third time before a change (HAS-295). An Eaton light is known only once the AMX confirmed it (HAS-308): its restored state has no `on` until a frame or a status answer, `FRAME_SERVER_UNAVAILABLE` of amx-service makes every Eaton light unknown, the unconfirmed are asked every 5 min (one in turn as a probe when all are confirmed); auto-off also switches off a light not known to be off. Own database `home-automation-light` (pool 2), `Recreate`, never scaled | **0.10.0** (2026-10-23, HAS-308) |

Do not confuse `api-gateway-service` (HTTP edge) with `amx-service` (AMX hardware bridge).

### Shared libraries (Maven, `cloud.cholewa` group)

| Library | Purpose | Current consumers | Latest |
|---|---|---|---|
| `cholewa-commons` | Common utilities: the error contract, the pooled R2DBC factory, English validation messages, the RabbitMQ connection name, `NotificationPublisher`, the required properties checked at the start (`cholewa.required-properties`, 1.9.0), Logbook in the reactive chain so that its lines carry the trace (1.10.0, HAS-298), the actuator left out of its log (1.10.1), a pool for the scheduler by default and `ScheduledPass.bounded` for every reactive `@Scheduled` pass (1.11.0, HAS-300) | ai, amx, api-gateway, blinds, boiler, database, heating, light, notification, presence, shelly-cloud, water, weather | **1.11.0** |
| `cholewa-security` | Security/auth | none yet — kept for possible future auth in `api-gateway-service` | **1.0.0** |
| `smart-home-sdk` | Shared domain / API models (household, device registry, calendar, device events) | amx, blinds, boiler, database, heating, light, presence, shelly-cloud, water, weather | **1.12.0** (HAS-260: `ShellyBinding.channel` 0-299 - a zone of a presence sensor) |
| `shelly-client` | Models of what a Shelly answers and publishes, reactive HTTP clients (Gen2+ RPC, Gen1) and the MQTT decoder | weather, blinds, heating, light, boiler (2.1.0 - boiler with its clients switched off); shelly-cloud, water (still on 1.0.0) | **2.1.0** |

Versions in the services (2026-10-23): `cholewa-commons` 1.11.0 on amx, blinds, boiler, heating, light and weather; 1.9.0 on api-gateway and database;
1.8.0 on notification; 1.7.0 on ai, shelly-cloud, water; 1.5.1 on presence.
`smart-home-sdk` 1.12.0 on amx, blinds, boiler, database, heating, light and weather; 1.6.0 on water; 1.3.0 on presence
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
  that bumps **removes its own `LogbookClientHandler`** (presence `AppConfig`;
  heating, blinds, light, boiler and weather done) or it logs
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

### Other repositories

- `amx` — AMX/NetLinx sources for the physical control system (not Java), on the personal
  account (`magikabdul/amx-tenczynek`); the workspace directory is named `amx`. The masters
  and their addresses are in `src/systemCholewaTenczynek.apw`.
- `web-application` — the dashboard: Angular 22 + Angular Material, desktop-first, installed as
  a PWA on the household's iPhones. Current release **0.27.0** (2026-10-22, HAS-267 — the editor of the rule of a room `/lights/rooms/{room}/rules` (administrator): auto-off, motion-on with its periods, the hold, the switch of the resident, checked by a copy of `RoomRuleRules` against the room as the device registry has it - a room on Eaton PIRs only gets no rule; `PUT` / `DELETE /home/light/rooms/{room}/rules`, read back; 0.26.0, HAS-268 — My room: a lights card for every member in a room with lights - the occupancy, every light with on / off, brightness and colour, all off, the rule in a few words and the switch of the resident (`PUT /home/light/rooms/{room}/rules/resident-enabled`, a rule answered without the field gets no switch); a lights tile on the overview (on / off / not known, the rooms lit, the empty house); 0.25.0, HAS-266 — the lights page `/lights` (administrator): every light of `light-service` by room with its occupancy, the rule in a few words, all off, and a window per room with brightness, the colour of an rgbw light, the sensors, the rule and the runs of 24 hours; new photos for every view; the heating page as four cards of one size and room tiles with a read-only schedule window - `heating-service` has no write of a schedule; one heating tile on the overview; 0.24.2, HAS-294 — the schedule editor refuses a threshold that can never be met, as blinds-service 0.9.0 does; 0.24.1, HAS-293 — the lights are read again 2.5 s after a command, so an Eaton light shows its new state within seconds; 0.24.0, HAS-292 — the Rooms view switches every light through `light-service` and shows its real state, the manual hold included; 0.23.1, HAS-254 — My room: the blinds of the room with their commands and the pause of their schedules, for every member in the rooms of their profile, the motion and presence sensors of the registry, the windows on the heating card; the blinds tile of the overview; 0.23.1 reads the 404 `NOT_FOUND_BLINDS` of a room without blinds as none; 0.22.0, HAS-253 — the editor of a schedule of the blinds under `/blinds/schedules`; 0.21.1, HAS-252 — the state of a blind in the words of `BlindState` (`open`); 0.21.0 — the blinds page "Rolety": the holidays and the whole house at the top, a card of one size per room with blinds, the schedules of a room in a window, the switch of a schedule; 0.20.0, HAS-232 — the Rooms view: every room with its devices by row, lights and blinds controlled from a room, the pause of the schedules of a blind; the windows and the hold on the heating page; the menu order overview, my room, weather, rooms; 0.19.1, HAS-290 — the devices page as a card of one size per room with the devices in a window, floors with Circulation, the opening sensors of blinds; 0.18.1, HAS-289 — the room `hall up`; 0.18.0, HAS-241 — the weather page with its six history charts; 0.17.0, HAS-240 — the weather strip on every page and the weather tile of the overview; 0.16.0, HAS-288 — the push button as a device kind; 0.15.1, HAS-231 — the
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
  - **It writes to the house in five places**: the heating switch (`POST
    /home/heating?turn=on|off`, after a question, never automated — browser tests run on a mock
    API; `npm start` talks to the real gateway), the two registries of `database-service`, and
    since 0.20.0 (HAS-232, the Rooms view, no question by the owner's choice) the blinds of
    `blinds-service` (commands, the pause of their schedules) and the lights - since 0.24.0 (HAS-292)
    every light through `light-service` (`POST /home/light/{id}`, `/brightness`, `source=dashboard`,
    which starts the manual hold), with the state of `GET /home/light`; the `amx-service` path it
    used before answered 404 since amx-service 2.0.0; since 0.21.0 (HAS-252) the room and whole-house
    commands of the blinds (the house is every room, one after the other) and the switch of a
    schedule of the blinds; since 0.22.0 (HAS-253) the editor of the schedules of the blinds
    (`POST`, `PUT`, `DELETE /home/blinds/schedules`; it checks a copy of `ScheduleRules`, so a
    rule changed in `blinds-service` is changed in the dashboard too); since 0.23.0 (HAS-254) **every
    member** commands and pauses the blinds of the rooms of their profile on My room (no permission,
    owner 2026-10-18), and since 0.26.0 (HAS-268) the lights of those rooms the same way, with the switch of the resident of the room rule, and My room reads `GET /home/device/registry?room=` - the device registry
    outside the administration, accepted as UI-only; since 0.27.0 (HAS-267) the editor of the rules of
    the rooms writes them (`PUT`, `DELETE /home/light/rooms/{room}/rules`, read back) and reads the
    registry of the room the same way.
    **Claude writes to the production registries only device by device, after the owner accepts
    each one** (the Eaton inventory of 2026-10-15 through the API, not the dashboard) — never
    from a test, never in bulk.
  - Endpoints it needs: `heating-service` ≥ 1.9.0, `water-service` ≥ 0.6.0, `database-service`
    ≥ 0.13.0, `weather-service` ≥ 0.4.0, `heating-service` ≥ 1.10.0 and `blinds-service` ≥ 0.8.0 for the Rooms and blinds views, `database-service` ≥ 0.14.0 for the holidays, `light-service` ≥ 0.6.0 and gateway ≥ 0.8.0 for the lights of the Rooms view, the lights page, the lights card of My room and the editor of the rules of a room; against an older one a card shows the 404 and the rest works.
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
    publisher that cares repeats. Publishers: `heating-service` (silent sensors),
    `boiler-service` (the boiler Shelly), `weather-service` (the weather station and its gateway), `light-service`
    (the Shelly lights and the sensors of the occupancy, the empty house), `blinds-service` (the Shelly blinds,
    unconfirmed commands) and `amx-service` (the frame server of the AMX master, HAS-309). `GET /home/notification/skippy?message=&level=`
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
- `weather-service` is routed the same way (gateway 0.6.0, HAS-239): exactly `GET /weather/current`,
  `/weather/status`, `/weather/history` - it serves reads only; **every new endpoint of
  `weather-service` needs a gateway release** too. A month of history answers in about 0.1 s
  through the ingress.
- `blinds-service` is routed by path, `/blinds` and `/blinds/**`, every method (gateway 0.7.0,
  HAS-251): the Shelly Gen1 rollers call `GET /home/blinds/events/gen1` through the host-less
  ingress - **a `GET` with a side effect by design** (a Gen1 device can only `GET`), an
  idempotent report of a state, so the repeat-once of a broken read is harmless for it.
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
- The gateway pins `spring-cloud-starter-gateway-server-webflux` (5.0.3) by hand: no release
  train targets Boot 4.1. **An accepted risk — re-test the gateway on every bump** of Boot or the
  starter (recipe in its `CLAUDE.md`: the jar with `home,local` and a stub, no cluster needed).

### Database

- One managed PostgreSQL with **22 usable connections for the whole cluster** (25 minus 3
  reserved), not for this project alone. Split: **heating 2 / database 4 / water 2 /
  presence 2 / blinds 2 / weather 2 / light 2 — 16 allotted, 6 free** for Flyway, tools and services to come. It is sized for
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
  (2026-08-13); its chronicle is in `history.md`. Every service is on Boot **4.1.1**, amx, blinds, boiler, heating, light and weather on **4.1.2**.
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
  `mockwebserver` (JUnit 4 — still in heating and water); a `MockWebServer` per test, no fixed
  port, no shared connection pool.
- **A publisher is verified as `publisher.as(StepVerifier::create)`** - the only acceptable form in
  every repository (owner, 2026-10-16); never `StepVerifier.create(publisher)`. Older tests are
  converted in the files a task touches (cholewa-commons still has them).
- **Repository tests**: H2 in a `@DataR2dbcTest` slice for portable statements; Testcontainers
  PostgreSQL for PostgreSQL-only SQL (heating and water fail without a Docker,
  `database-service` skips without one — but not where `CI=true`).
- **Code moves into `cholewa-commons` only when more than three services use it** (owner,
  2026-10-11). Up to three copies stay — no review finding, no task; note the copy in each
  service's `CLAUDE.md` (today: `NotificationRabbitConfig`, **five copies** — heating, blinds,
  weather, light, amx: the fourth and the fifth kept by the owner's choice (HAS-257, HAS-309), do not re-raise;
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
  (new), `heating-service`, `light-service` (new), `boiler-service`; 8 repositories still have the old form.

## Working rules for Claude

- **Spring Boot services and libraries**: the user writes the code themselves. Do NOT write
  or modify code there unless explicitly asked. Default contributions: analysis, code
  review, security review, answering questions.
- **`web-application`**: full autonomy — Claude designs and implements the frontend.
- **`amx`**: NetLinx language; analysis and suggestions, ask before modifying. The owner
  writes the NetLinx code and transfers it to the masters.
- Never commit or push unless explicitly asked.
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
