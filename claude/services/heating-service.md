# heating-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6002.

## Depends on - read also

- Calls over HTTP: `database-service`.
- Called by: `api-gateway-service`, `boiler-service`, `aircon-service` (and the dashboard through the gateway).
- Broker: consumes `/temperature` (from amx-service) and `device.prod.heating`; alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `boiler-service.md`, `aircon-service.md` - and the contracts in `../organization.md`.

## What it does

Heating control; watches the temperature sensors (an alert after 24 h of silence); serves the rooms, the floor pump and the stored temperature history read-only — the contract of the dashboard. Open windows (HAS-232): the opening sensors of a room from the registry and the BTHome gateways (a copy of `WindowSensors` of blinds-service, per room), the `bthomesensor` topics of `device.prod.heating` over a third connection to `/device` (`device-rabbitmq-password`); a window or door open for `heating.window.hold-after` (**PT3M**) holds every heater of the room (checked every minute too), an unknown sensor never holds and a silent one is an alert; `GET /rooms` answers `window` (`state` as in blinds, `openSince`, `hold`). Its Logbook lines carry the `traceId` since 1.11.0 (HAS-298, the first consumer of `cholewa-commons` 1.10.0; its own `LogbookClientHandler` are gone; 1.11.1 - the actuator out of the log)

## Releases

- **1.23.2** (2026-11-13, HAS-433: imports instead of fully qualified names, the MapStruct expression through `@Mapper(imports)`; smart-home-sdk 1.21.0
- 1.23.1, 2026-11-12, HAS-421: the write of a window sensor reading bounded at 30 s - it is part of the chain of the device listener
- 1.23.0, 2026-11-11, HAS-419: the last reading of every window sensor stored in `window_sensor_reading` (V7) and read back at the start as not confirmed - an older value a restarted gateway restores is ignored (an INFO once per sensor and start), an equal or newer one confirms or replaces it
- 1.22.0, 2026-11-10, HAS-413: every night at 03:35 the room temperatures and the changes of the house switch older than `heating.retention` (730d) deleted, never the latest change of the switch
- 1.21.1, HAS-215: the 404 of an unknown room answered by `DomainExceptionProcessor` of cholewa-commons 1.14.0, the body unchanged; smart-home-sdk 1.19.0, shelly-client 2.7.0
- 1.21.0, 2026-11-07, HAS-388: the radiator of sanctum left to its air conditioner - its schedules kept for aircon-service (`shelly.actor.relay.schedule-only`), its plug neither read nor switched, the furnace hears only the relays of the Pro 4; smart-home-sdk 1.18.0, shelly-client 2.6.0
- 1.20.0, HAS-350: a window sensor stuck open while its room needs heat - one warn on Discord after `heating.window.stuck-open-after` (PT6H) without a new window value from its gateway, while the room is held and would heat (the house on, a heater in schedule below its target); one info with a newer value, no reminder; `opening_sensor_open_alert` (V6)
- 1.19.0, HAS-368: the temperature of the sauna from its Gen1 Shelly 1 with the temperature add-on (registry 138), polled every minute - `heating.thermometer.gen1-poll`, the same value every 10 min at most; shelly-client 2.4.0
- 1.18.0, HAS-364: the BLU H&T of the bathrooms read through the BTHome gateways that hear them (registry 136 / 137) - temperature and humidity from the gateway read of the window sensors and the `bthomesensor` topics, dated when heard, older than 30 min not taken, the Eaton sensors 8 / 11 of the bathrooms removed from the registry on 2026-11-02 (HAS-365), so both are read from the BLU alone, of two thermometers in a room the newer reading wins
- 1.17.0, HAS-361: the radiator of sanctum a standalone Shelly Plug S Gen1 (`shelly.actor.relay.standalone`) driven by its schedule and the house switch, never counted in `GET /status/active` - the cloud scenes disabled
- 1.16.0, HAS-360: a room without an Eaton room sensor read from its Shelly thermometer of the registry - the Plus H&T of sanctum, `temperature:0` / `humidity:0` of `device.prod.heating`, humidity in `GET /rooms`; the heaters it does not drive skipped by the decision; cholewa-commons 1.13.0
- 1.15.0, HAS-358: a day off on Monday to Friday runs the Sunday schedules - the type of today from the calendar of `database-service` (`GET /home/calendar/days`), asked at the start and daily in the minute decision, the weekday when it cannot be read
- 1.14.0, HAS-356: the schedules written through the API - `POST /rooms/{room}/heaters/{heater}/schedules`, `PUT` / `DELETE /schedules/{id}`, `PUT /schedules/{id}/enabled`; `ScheduleRules` (days, `HH:mm`, 5-30 °C by 0.5, no overlap within a heater) copied by the dashboard, `INVALID_SCHEDULE` / `NOT_FOUND_SCHEDULE` / `NOT_FOUND_HEATER`
- 1.13.0, HAS-355: the 30 heating schedules stored in `heating_schedule` (V5) and loaded into the heaters before the listeners start, `id` / `enabled` per schedule in `GET /rooms`, a disabled one never covers
- 1.12.0, HAS-352: every room decided every minute and right after the switch, not only at its reading; cholewa-commons 1.12.0, smart-home-sdk 1.15.0
- 1.11.2, HAS-303: every scheduled task bounded)
