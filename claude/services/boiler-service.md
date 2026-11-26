# boiler-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6007.

## Depends on - read also

- Calls over HTTP: `heating-service`, `water-service`.
- Called by: `api-gateway-service` (and the dashboard through the gateway).
- Broker: alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `heating-service.md`, `water-service.md` - and the contracts in `../organization.md`.

## What it does

Drives the furnace and both pumps as relays of one Shelly Pro 4; alerts when that Shelly stops answering (HAS-109)

## Releases

- **1.4.0** (2026-10-23, HAS-306: the control pass bounded at 3 min, cholewa-commons 1.11.0)
