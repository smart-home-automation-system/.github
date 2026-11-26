# blinds-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6011.

## Depends on - read also

- Calls over HTTP: `database-service`, `amx-service`, `weather-service`.
- Called by: `api-gateway-service`, `safety-service` (and the dashboard through the gateway).
- Broker: consumes `device.prod.blinds` (the Eaton events of amx-service among them); alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `amx-service.md`, `weather-service.md`, `safety-service.md` - and the contracts in `../organization.md`.

## What it does

Roller shutters (epic HAS-242): Eaton blinds through `amx-service`, Shelly blinds, the real state, weather-aware schedules. Knows the blinds from the device registry (every 5 min) and moves them on command through three drivers - Shelly Gen1 roller, Shelly Gen2 cover, Eaton through `amx-service` (HAS-244); `POST /home/blinds/{id}`, `/{id}/position`, `/rooms/{room}`. Tracks the real state of every blind (HAS-245): Gen2 covers from `device.prod.blinds` (MQTT) plus `Cover.GetStatus` every 5 min, Gen1 rollers by `/status` every 60 s and their `roller_*_url` actions on `GET /home/blinds/events/gen1` (open / close when a roller starts, stop when it stops - then `/status` is read; 0.8.1, configured on the eight rollers in HAS-255), Eaton from the `status` events of `amx-service`; table `blinds_state`; `GET /home/blinds`, `/rooms/{room}`, `/{id}`. Stores the schedules (HAS-246): CRUD under `/schedules`, `INVALID_SCHEDULE` / `NOT_FOUND_SCHEDULE` (texts for the dashboard, HAS-253). Confirms an Eaton move with a status request when its start is not reported (HAS-291). Runs them (HAS-247): every minute from the calendar of `database-service`, the sun (`location-latitude` / `-longitude` of the manifest) and `GET /home/weather/current` (an unknown input never holds), once a window per schedule and blind (`blinds_schedule_run`); `GET /schedules/{id}/today`. Window sensors per blind (HAS-290): the BLU Door/Window sensors linked by `openingSensors`, read from the registered `bthome gateway` devices (`Shelly.GetComponents` every 5 min, `bthomesensor` status topics between); a BLU sensor has no heartbeat, so a state holds while its gateway confirms it (`blinds.window.gateway-silent-after`, PT30M); `window closed` is judged per blind with its own hold; `GET /home/blinds` and `/today` show the window (`closed`, `open`, `no sensor`, `unknown`); a schedule window may cross midnight and belongs to the day it opened on. The pause of the schedules of one blind (HAS-232, supersedes HAS-248): `PUT` / `DELETE /home/blinds/{id}/schedule-pause`, ends by itself with the next run it prevents (stored as `PAUSED`, V4); `GET /home/blinds/{id}/schedules` (today, per blind); `schedulePausedSince` in the reads. Routed by path, every method (gateway 0.7.0, HAS-251). A condition `lt` at the least of its range or `gt` at the most is refused - never true for the strict comparison (HAS-294, `illuminance lt 0`). Every command waits for the report that answers it (HAS-250, 60 s for a Gen2+ cover, 2 min for Gen1 and Eaton): unanswered is `lastCommandConfirmed: false` in the reads, the third in a row an alert; a Shelly blind unreachable for 5 min is an alert, reminded hourly, an info on its return (open alerts in `blinds_availability_alert`, V5; Eaton not watched). Own database, `Recreate`, never scaled

## Releases

- **0.12.0** (2026-11-22, HAS-466: the command source `safety` - safety-service opening the blinds of the room of a fire alarm, stored as it comes, no schedule paused; Boot 4.1.3, smart-home-sdk 1.24.0
- 0.11.1, 2026-11-13, HAS-434: imports instead of fully qualified names in the tests; smart-home-sdk 1.21.0
- 0.11.0, 2026-11-12, HAS-420: the last reading of every window sensor stored in `window_sensor_reading` (V6) and read back at the start as not confirmed - an older value a restarted gateway restores is ignored, a write bounded at 30 s; cholewa-commons 1.14.0, smart-home-sdk 1.19.0, shelly-client 2.7.0
- 0.10.1, 2026-10-22, HAS-301: every scheduled task bounded, the scheduler pool of cholewa-commons 1.11.0)
