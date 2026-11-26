# safety-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6017.

## Depends on - read also

- Calls over HTTP: `database-service`, `light-service`, `blinds-service`, `aircon-service`.
- Called by: `api-gateway-service` (and the dashboard through the gateway).
- Broker: consumes `device.prod.safety` and publishes the detector commands to `/device`; `household` (the fire alarm) and alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `light-service.md`, `blinds-service.md`, `aircon-service.md` - and the contracts in `../organization.md`.

## What it does

The fire detectors of the house (epic HAS-455): the X-Sense detectors of the device registry (`smoke detector`, `co detector`, `heat detector` with an `xsense` binding, every 5 min) and their state from what the SBS50 base station publishes over MQTT - `device.prod.safety` of `/device` (user `device`, definitions 1.10.0; the topics in `deployment-tools/scripts/xsense/devices.md`): alarm, online, battery, end of life, fault, muted, the self test, the availability and network of the base.

Since HAS-460 the state in memory, written off the listener path to `detector_state` / `base_state` (V1, upserts that never let an older snapshot win nor a value not known replace a stored one) and read back at a start as not confirmed; the birth message (`online` to `homeassistant.status`) asks the base to republish once the registry is known, then hourly; `GET /home/safety`, `/rooms/{room}`, `/{id}` (routed since gateway 0.13.0, HAS-459; `REGISTRY_UNAVAILABLE`, `NOT_FOUND_ROOM`, `NOT_FOUND_DETECTOR`).

Since HAS-461 a fire alarm: `smokealarm` Detected opens an episode in `detector_alarm` (V2, one open per detector), Cleared closes it, decided by the open episodes in memory; `fire alarm` / `fire alarm over` published to the `household` category (notification-service >= 0.14.0 texts and pushes it to every member at home or not) over a second connection to `/notification` (user `notification`), the household told whatever the database says (5 s at most for the row); `GET /home/safety/alarms?from=&to=` (at most 30 days, `INVALID_RANGE`).

Since HAS-463 the technical monitor: every minute a detector offline, low on battery, at its end of life or faulty, a base offline (back once anything comes from it after its last will) or silent (nothing for 30 min; the base is asked to republish every 10 min) - one alert a pass on the technical channel naming everything, hourly reminders, the return, never the household nor an SMS; episodes in `safety_alert` (V3); `GET /home/safety/status`.

Since HAS-464 the commands of a detector: `POST /home/safety/{id}/mute`, `/{id}/self-test` (`?source=`), one per detector a minute (`429 COMMAND_TOO_SOON`), published once to its `cmd` topic of the base over `/device` and confirmed only by what the base reports within 60 s (`lastCommandConfirmed`, the third unconfirmed in a row an alert), `safety_command` (V4), `GET /{id}/commands`; **a mute only of a detector in alarm** (`409 NOTHING_TO_MUTE` - the base ignores a mute of a quiet detector, tried 2026-11-21; a self test sounded and was confirmed in 5.5 s).

Since HAS-468 the reactions to a fire alarm, each behind a switch of the administrator, all off by default (`safety_automation`, V5, `GET` / `PUT /home/safety/automation`, `INVALID_AUTOMATION`): once per newly opened episode, beside the household, `lightsOn` the room of the detector and hall down / hall up (light-service), `blindsUp` the blinds of its room (blinds-service), `airconOff` every unit on (aircon-service) - each with `source=safety` (all three >= 0.12.0), its own outcome (404 is none), bounded at 30 s together, nothing switched back; `safety_reaction_run` (V6), `GET /home/safety/automation/runs?from=&to=`; the furnace never touched. Own database `home-automation-safety` (pool 2), `Recreate`, never scaled

## Releases

- **0.5.0** (2026-11-22, HAS-468: the reactions to a fire alarm behind three switches, all off by default - the lights of the room and both halls on, the blinds of the room up, every air conditioner on off, each with `source=safety`, V5 / V6, `GET` / `PUT /automation`, `GET /automation/runs`; proven 2026-11-22 on an injected Detected of the office with the owner
- 0.4.1, 2026-11-21, HAS-464: a mute only of a detector in alarm - 409 NOTHING_TO_MUTE
- 0.4.0, 2026-11-21, HAS-464: the mute and the self test of a detector over MQTT
- 0.3.0, 2026-11-20, HAS-463: the technical monitor of the detectors and the base
- 0.2.0, 2026-11-20, HAS-461: the fire alarm episodes and the household told
- 0.1.0, 2026-11-20, HAS-460: the detectors from the registry and their state from the MQTT of the base; Boot 4.1.3, cholewa-commons 1.14.0, smart-home-sdk 1.24.0)
