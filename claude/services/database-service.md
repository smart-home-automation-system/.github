# database-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6005.

## Depends on - read also

- Calls over HTTP: no service.
- Called by: `api-gateway-service`, `amx-service`, `heating-service`, `notification-service`, `water-service`, `presence-service`, `weather-service`, `blinds-service`, `light-service`, `appliance-service`, `energy-service`, `aircon-service`, `gate-service`, `safety-service` (and the dashboard through the gateway).
- Broker: none.
- **Before a change that touches what crosses these lines, read their files too**: `amx-service.md`, `heating-service.md`, `notification-service.md`, `water-service.md`, `presence-service.md`, `weather-service.md`, `blinds-service.md`, `light-service.md`, `appliance-service.md`, `energy-service.md`, `aircon-service.md`, `gate-service.md`, `safety-service.md` - and the contracts in `../organization.md`.

## What it does

Persistence facade: the household registry (members, devices, roles, rooms, permissions; the profiles of the dashboard), the **device registry** of every device of the house (read and written; the Eaton configuration `amx-service` asks for is served from it) and the **calendar of the house** (days off);

since 0.16.0 the `openingSensors` of blinds (V16, each a registered opening sensor; a sensor in use is not removed - `DEVICE_CONFLICT`);

since 0.17.0 a `presence sensor` may have a zone (200-299, `presencezone:200`) as its Shelly channel (V17);

since 0.18.0 the `appliance` with its eight settings (V18) and the Web Push subscriptions of the members (V19, `push_subscriptions`): `PUT` / `DELETE /household/member/{name}/push-subscriptions`, `GET /household/push-config` (the public VAPID key, `HOUSEHOLD_PUSH_PUBLICKEY`, `{}` without one), and `GET /push-subscriptions?members=` for notification-service - outside every routed prefix, cluster only (a dot segment below `/household` answers 404, checked through the ingress); a switched-off member is `409 MEMBER_SWITCHED_OFF`;

since 0.19.0 `DELETE /push-subscriptions?endpoint=` (cluster only) removes a subscription a push service dropped (HAS-276);

since 0.20.0 the kind `inverter` with its `inverter` binding (V20: brand, serial number - one device per serial, address, the SolaX dongle registration or the Solarman logger serial, the battery serial; HAS-326) - 0.19.0 cannot read a stored inverter, no rollback below 0.20.0;

since 0.21.0 the kind `water valve` (a Shelly of generation 2 or later on the channel 0, no migration; HAS-311) - 0.20.0 cannot read a stored valve, no rollback below 0.21.0;

since 0.23.0 the kind `air conditioner` (HAS-378, `GreeBinding`, vendor `gree`);

since 0.25.0 the kind `air quality sensor` (HAS-425, `BleboxBinding`, vendor `blebox`, V24 - one device per id and per address) - 0.24.x cannot read a stored sensor, no rollback below 0.25.0;

since 0.26.0 the kinds `intercom` (`HikvisionBinding`, vendor `hikvision`, V25 - one station per serial number and per address) and `gate` (a Shelly on the channel 0 only) (HAS-445) - 0.25.x cannot read either, no rollback below 0.26.0 (the station is 146, the gate Shelly 147 since 2026-11-17);

since 0.27.0 the `openingSensors` of a `gate` (HAS-471, V26 - the check of V16 kept the list to blinds; a gate with sensors is a garage gate, a sensor a gate names is not removed - `DEVICE_CONFLICT`; the garage gates are 148 Kate and 149 Kris, registered disabled until HAS-473);

since 0.28.0 the kinds `smoke detector`, `co detector` and `heat detector` (HAS-457, `XsenseBinding`, vendor `xsense`, V27 - one detector per pair of the base station and its id) - 0.27.x cannot read a stored detector, no rollback below 0.28.0; the dashboard knows them since 0.58.0 (HAS-458); the eleven smoke detectors registered on 2026-11-20 (ids 150-160, `deployment-tools/scripts/xsense/devices.md`);

since 0.22.0 the household requests (HAS-409, epic HAS-407, `MemberRequest` of SDK 1.17.0): `member_requests` (V21, by `member_id`), `GET` / `POST /household/member/{name}/requests`, `PUT .../{id}/done?member=`, `DELETE .../{id}`, and for notification-service `GET /household/requests?pending=true` and `PUT /household/requests/sent` - below the routed `/household`, so reachable through the gateway; `INVALID_REQUEST`, `NOT_FOUND_REQUEST`; the done ones older than 30 days deleted with the next write

## Releases

- **0.28.0** (2026-11-19, HAS-457: the fire detectors in the registry, V27, SDK 1.24.0
- 0.27.0, 2026-11-18, HAS-471: the opening sensors of a gate, V26, SDK 1.23.0
- 0.26.0, 2026-11-17, HAS-445: the intercom and the gate in the registry, V25, SDK 1.22.0
- 0.25.1, 2026-11-13, HAS-436: imports instead of fully qualified names, the MapStruct expressions through `@Mapper(imports)`; smart-home-sdk 1.21.0
- 0.25.0, 2026-11-12, HAS-425: the kind `air quality sensor` of the vendor `blebox`, its `blebox` binding (V24) - 0.24.x cannot read a stored sensor, no rollback below 0.25.0; SDK 1.20.0
- 0.24.1, 2026-11-10, HAS-214: `DomainExceptionProcessor` taken from cholewa-commons 1.14.0, its own copy deleted, the bodies unchanged
- 0.24.0, HAS-415: the marks of the reminders and the announcements of the household requests (V23: `reminded_at`, `done_announced_at`, `stale_announced_at`, the done ones before it counted as announced), three reads for notification-service - `GET /household/requests/done-to-announce`, `/to-remind?remindedBefore=`, `/stale?sentBefore=` - and three marks `PUT /household/requests/reminded`, `/done-announced`, `/stale-announced`; a request ticked off by its own author is announced at once; SDK 1.19.0
- 0.23.0, 2026-11-07, HAS-378: the kind `air conditioner` of the vendor `gree`, its `gree` binding (V22, one device per MAC and per address) - 0.22.0 cannot read a stored unit, no rollback below 0.23.0
- 0.22.0, HAS-409: the household requests
- 0.21.0, HAS-311: the water valve
- 0.20.0, HAS-326)
