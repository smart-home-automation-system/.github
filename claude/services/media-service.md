# media-service

What this service does and its release history - the detail a task on this service, or on a service that talks to it,
reads first. Its own `CLAUDE.md` and README go deeper. Local port 6018.

## Depends on - read also

- Calls over HTTP: `database-service` (`GET /home/household/profiles`, the member who presses) and the amplifier on the
  LAN (`deployment-tools/scripts/media/amplifier.md`).
- Called by: `api-gateway-service` (`/media`, `/media/**`, every method - gateway 0.14.0, HAS-516) and through it the
  dashboard (HAS-517).
- Broker: none. Database: none.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`,
  `api-gateway-service.md`, `web-application.md` - and the contracts in `../organization.md`.

## What it does

The audio and video equipment of the house (owner, 2026-11-24). Its first job is the unlock of the amplifier (epic
HAS-508): the Harman Kardon amplifier hangs after every loss of the grid and works again once any file is sent to the
firmware form of its web page; a member with `amplifier_unlock` presses a button in the dashboard. Its state cannot be
read - never design a status or a detection, and the unlock is a button only, never automatic (owner, 2026-11-24; the
rules are in the `CLAUDE.md` of the repository since HAS-515).

Since HAS-515 the unlock: `POST /home/media/amplifier/unlock?source=dashboard&member=` sends one `POST
/goform/formPostHandler` (multipart, the file `appFirmware` of a few bytes and `appFirmwareFile=Upload`); the 302 to
`.../bl_bcd_error.asp` is the success (202). Sent once, never retried, one at a time (409 `UNLOCK_IN_PROGRESS`); the
member checked against the profiles and `amplifier_unlock` (400 `UNKNOWN_MEMBER`, 403 `NOT_PERMITTED`, 503
`REGISTRY_UNAVAILABLE`); 502 `AMPLIFIER_REFUSED`, 503 `AMPLIFIER_UNAVAILABLE`, 504 `AMPLIFIER_TIMEOUT`. The address of the
amplifier is `amplifier-address` of the manifest, required. Not routed before HAS-516.

Since HAS-514 a scaffold: Spring Boot 4.2.0, `cholewa-commons` 2.0.0 (the error contract), `smart-home-sdk` 1.26.0;
stateless - no database, no broker, so the Deployment rolls (`RollingUpdate`). Base path `/home/media`, scraped by
Prometheus under `app="media-service"`.

## Releases

- **0.2.0** (2026-11-27, HAS-515: the unlock of the amplifier)
- 0.1.0 (2026-11-26, HAS-514: the scaffold - an empty service that answers its probes)
