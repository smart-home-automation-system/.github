# gate-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6016.

## Depends on - read also

- Calls over HTTP: `database-service`, `weather-service`, `presence-service`, `amx-service`.
- Called by: `api-gateway-service`, `amx-service` (and the dashboard through the gateway).
- Broker: consumes `device.prod.gate` (the Hikvision bridge); `household` and alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `weather-service.md`, `presence-service.md`, `amx-service.md` - and the contracts in `../organization.md`.

## What it does

The driveway gate and the intercom (epic HAS-442): the events of the Hikvision door station at the gate from the SDK bridge of the cluster (`hikvision-bridge` of deployment-tools, the MQTT topics `hmd.*.gate.*` on `device.prod.gate` of `/device` - the contract in `deployment-tools/scripts/hikvision/devices.md`; no picture, the station gives none), the command of the Shelly 1 of the gate, their log and the household told.

Since HAS-446 the scaffold: base path `/home/gate`, own database `home-automation-gate` (pool 2, `V1` an empty baseline), `Recreate`, never scaled; the station and the gate Shelly are registry devices 146 (`intercom`) and 147 (`gate`, channel 0).

Since HAS-448 the events of the station: `device.prod.gate` on `/device` (user `device`, `rabbitmq-password`), a ring with its button, a dismissed call, an unlock of the attributes of `Door-<n>-relay` at its `last_unlocked` (UTC of the bridge, moved into the time of the house) stored in `intercom_event` (V2) - an unlock once by its door and time (`intercom_event_unlock_uq`; HAS-449 opens the gate only for a new row); the availability of the bridge in memory.

Since HAS-449 the gate opened: the gate of the registry (`?kind=gate&enabled=true`) and the `auto_off` of its relay read every 5 min - safe only above 0; one `/relay/0?turn=on` of the Shelly 1 Gen1, never retried, at most one in `gate.open.ignore-repeat-for` (PT15S, `OPEN_TOO_SOON`); every unlock `HOUSEHOLDER` from an indoor screen of `gate.screens` younger than PT1M opens it at once (not waiting for the database; first real opening 2026-11-18 10:56, about 140 ms after the bridge); `POST /home/gate/open?source=dashboard&member=` (the member checked against the profiles), `GET /home/gate`, `gate_command` (V3) - the codes of `GateError` wire contract for the dashboard. Routed by path, every method (gateway 0.12.0, HAS-447).

Since HAS-450 `GET /home/gate/events?from=&to=` - the rings, dismissed calls and unlocks of the station and the commands of the gate as one timeline, the newest first (at most 31 days, `INVALID_RANGE`; no picture - the station gives none), and both tables kept 90 days (`gate.retention`, deleted nightly at 03:40).

Since HAS-452 the household told (the `household` category over a second connection to `/notification`, user `notification`, read by notification-service >= 0.12.0): `doorbell ringing` once per call (none within `gate.doorbell.ignore-repeat-for`, 60 s, of the last one told; a ring that could not be told gives the window back), its subject the door station of the registry, `acknowledgePath` `/gate`; `gate opened` after a pulse the Shelly took, with `source` and `member` - checked on a real ring and a real opening from the screen on 2026-11-18.

Since HAS-473 the garage gates: a gate with `openingSensors` (database-service >= 0.27.0) is a garage gate kept apart from the driveway gate (147 stays the one the screen opens) - 148 Kate and 149 Kris, switched on 2026-11-18; the state of each from the BLU Door/Window sensor on it through its BTHome gateway (GRID POWER), `Shelly.GetComponents` every 5 min and the `bthomesensor` topics between, not known after 30 min of silence of the gateway (`gate.garage.gateway-silent-after`) - the copy of the window sensors of blinds-service (the third with heating-service); `garage_sensor_reading` (V4, per sensor) read back at a start as not confirmed; `GET /home/gate/garage`, `/garage/{id}` (`NOT_FOUND_GATE`); a pulse opened Kate and the read said so within 4 s.

Since HAS-475 the alarms of a garage gate left open, judged every minute (replacing the Shelly cloud scene GARAGE NOTIFICATION, its midnight check not moved): cold - open 15 min below 15 C outside (weather-service over k8s DNS), empty house - open while nobody is at home for 5 min (presence-service, the fifth copy of its client - kept by the owner's choice, 2026-11-18), both repeated every 30 min; long - open 30 min, a warning repeated hourly, never while an alarm holds; at most 10 repeats, closed told once; episodes in `garage_gate_alert` (V5), written only once told; the thresholds `gate.garage.alarm.*`; proven by real events, never staged (owner).

Since HAS-474 the pulse of a garage gate - `POST /home/gate/garage/{id}/pulse?source=dashboard&member=`, one pulse never retried, **no repeat window** (owner 2026-11-18: a second press stops the gate half-way), `lastCommandConfirmed` judged by a change of the state its sensor reports (the clock of the gateway runs ahead of the cluster), not by a clock; V6: `gate_command.gate_id` and the outcome `PULSED`, `garage_gate_change` - every change of a garage gate, in `GET /events` as the kind `garage`, kept 90 days, a change written once it held for 5 s (0.8.1 - the sensor bounces at both ends of the travel).

Since HAS-453 the availability monitor, every minute on the technical channel (no SMS): the bridge by its `availability` topic alone (offline for 5 min - owner 2026-11-19: it publishes nothing while nothing happens at the gate, so no silence is judged), the Shelly of every gate not answering its `/status` for 5 min, a relay with `auto_off` 0 at once, a garage gate not known for 5 min; one alert, an hourly reminder and one return a pass naming everything, an alert that never got through announced with the return (`gate_availability_alert`, V7).

Since HAS-454 `GET /home/gate/garage/alerts` - the open alarms and warnings of the garage gates (kind cold / empty house / long, level alarm / warning), for the gate page of the dashboard.

Since HAS-485 every ring wakes the entrance panel - `POST /home/amx/panel/doorbell` of amx-service (>= 2.6.0, k8s DNS, `internal.service.amx`) beside the stored ring and the household message, not behind its 60 s window; bounded at 5 s, a failure a WARN (503 until the panel server of the Office master runs)

## Releases

- **0.12.0** (2026-11-23, HAS-485: every ring wakes the entrance panel through amx-service; checked on a real ring - the call 70 ms after the bridge message
- 0.11.0, 2026-11-22, HAS-483: the gate opened for the entrance panel - `POST /open?source=panel` without a member, told as `gate opened` from the panel, `gate_command` takes `PANEL` (V8); proven on the real gate with the owner 2026-11-22; Boot 4.1.3, smart-home-sdk 1.25.0
- 0.10.0, 2026-11-19, HAS-454: GET /garage/alerts
- 0.9.0, 2026-11-19, HAS-453: the availability monitor
- 0.8.2, 2026-11-19, HAS-474: the findings of the review of 0.8.1 - a change the bound of its pass cut off is put back, never lost without a word
- 0.8.1, 2026-11-19, HAS-474: the bounce of a garage gate sensor filtered out of its history
- 0.8.0, 2026-11-19, HAS-474: the pulse of a garage gate and its history
- 0.7.0, 2026-11-18, HAS-475: the alarms of an open garage gate
- 0.6.0, 2026-11-18, HAS-473: the garage gates and their state from the opening sensors
- 0.5.0, 2026-11-18, HAS-452: the doorbell and the gate told to the household
- 0.4.0, 2026-11-18, HAS-450: the events API and the retention
- 0.3.0, 2026-11-18, HAS-449: the gate opened from the indoor screen and the API
- 0.2.1, 2026-11-18, HAS-448: the broker password from its variable - 0.2.0 shipped a literal one and crash-looped
- 0.2.0, 2026-11-17, HAS-448: the events of the door station
- 0.1.0, HAS-446: the scaffold)
