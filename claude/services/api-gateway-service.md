# api-gateway-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6200.

## Depends on - read also

- Calls over HTTP: `ai-service`, `aircon-service`, `amx-service`, `appliance-service`, `blinds-service`, `boiler-service`, `database-service`, `energy-service`, `gate-service`, `heating-service`, `light-service`, `presence-service`, `safety-service`, `water-service`, `weather-service`.
- Called by: no service (and the dashboard through the gateway).
- Broker: none.
- **Before a change that touches what crosses these lines, read their files too**: `ai-service.md`, `aircon-service.md`, `amx-service.md`, `appliance-service.md`, `blinds-service.md`, `boiler-service.md`, `database-service.md`, `energy-service.md`, `gate-service.md`, `heating-service.md`, `light-service.md`, `presence-service.md`, `safety-service.md`, `water-service.md`, `weather-service.md` - and the contracts in `../organization.md`.

## What it does

Spring Cloud Gateway — the **only** entry point into the cluster from outside; static routes to the services over k8s DNS (see External traffic)

## Releases

- **0.13.0** (2026-11-20, HAS-459: route safety; Spring Boot 4.2.0 and the Spring Cloud train 2026.0.0 - the starter 5.1.0 from its BOM, the hand pin gone
- 0.12.0, 2026-11-18, HAS-447: route gate; cholewa-commons 1.14.0
- 0.11.0, 2026-11-07, HAS-379: route aircon - a 502 with a body until aircon-service runs
- 0.10.0, HAS-325: route energy)
