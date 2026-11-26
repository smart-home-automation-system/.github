# media-service

What this service does and its release history - the detail a task on this service, or on a service that talks to it,
reads first. Its own `CLAUDE.md` and README go deeper. Local port 6018.

## Depends on - read also

- Calls over HTTP: nothing yet; with HAS-515 `database-service` (`GET /home/household/profiles`) and the amplifier on
  the LAN.
- Called by: nobody yet; with HAS-516 `api-gateway-service` (`/media`, `/media/**`) and through it the dashboard
  (HAS-517).
- Broker: none. Database: none.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`,
  `api-gateway-service.md`, `web-application.md` - and the contracts in `../organization.md`.

## What it does

The audio and video equipment of the house (owner, 2026-11-24). Its first job is the unlock of the amplifier (epic
HAS-508): the Harman Kardon amplifier hangs after every loss of the grid and works again once any file is sent to the
firmware form of its web page; a member with `amplifier_unlock` presses a button in the dashboard. Its state cannot be
read - never design a status or a detection (owner, 2026-11-24; `working-rules.md`).

Since HAS-514 a scaffold: Spring Boot 4.2.0, `cholewa-commons` 2.0.0 (the error contract), `smart-home-sdk` 1.26.0;
stateless - no database, no broker, so the Deployment rolls (`RollingUpdate`). Base path `/home/media`, scraped by
Prometheus under `app="media-service"`.

## Releases

- **0.1.0** (2026-11-26, HAS-514: the scaffold - an empty service that answers its probes)
