# presence-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6009.

## Depends on - read also

- Calls over HTTP: `database-service`.
- Called by: `api-gateway-service`, `notification-service`, `water-service`, `light-service`, `appliance-service`, `aircon-service`, `gate-service` (and the dashboard through the gateway).
- Broker: alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `notification-service.md`, `water-service.md`, `light-service.md`, `appliance-service.md`, `aircon-service.md`, `gate-service.md` - and the contracts in `../organization.md`.

## What it does

Household presence: UniFi clients matched against the household registry every minute, status changes stored, four routed reports, nightly retention (`P365D`).

Since HAS-476 a detection that does not run is told: no pass evaluated for `presence.alert.skipped-after` (PT10M) an alert on the technical channel naming the cause in fixed words (the gateway, the registry, the database, the pass timeout; a foreign certificate names the fingerprint), a reminder hourly, one info at the return (an untold alert announced with it), in memory; a pass not one of whose decisions could be written counts as skipped; its one broker connection to `/notification` (user `notification`). State in the memory of one instance: `Recreate`, never scaled

## Releases

- **0.8.0** (2026-11-26, HAS-511: the household registry read with the permission `amplifier_unlock` (SDK 1.26.0, epic HAS-508); Spring Boot 4.2.0, cholewa-commons 2.0.0, `spring-boot-starter-rabbitmq` - the connection `<pod>` in `/notification` opens on the first use, e.g. a read of the health)
- 0.7.0 (2026-11-19, HAS-476: the alert of skipped passes, the certificate of the gateway since 2026-11-17 (until 2029-02-18) - the override of the manifest removed; cholewa-commons 1.14.0, smart-home-sdk 1.23.0
- 0.6.1, 2026-10-23, HAS-305: both passes bounded, cholewa-commons 1.11.0; the UniFi calls logged by its own body-less Logbook filter)
