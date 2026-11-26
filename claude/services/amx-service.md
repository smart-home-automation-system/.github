# amx-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6001.

## Depends on - read also

- Calls over HTTP: `database-service`, `weather-service`, `gate-service`.
- Called by: `api-gateway-service`, `blinds-service`, `light-service`, `gate-service` (and the dashboard through the gateway).
- Broker: publishes the room temperatures to `/temperature` (read by heating-service) and the Eaton `DeviceEvent` to `/device` (read by blinds-service and light-service); alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `weather-service.md`, `gate-service.md`, `blinds-service.md`, `light-service.md` - and the contracts in `../organization.md`.

## What it does

Bridge to the AMX control system over **one permanent TCP socket to the frame server of the Television master** (port 20010, NetLinx side HAS-230): receives every Eaton frame of both gateways and publishes the readings, **sends** Eaton frames (blinds, lights, levels) the other way; publishes what an Eaton blinds, light, dimmer, push button or PIR sensor reports as `DeviceEvent` to `/device` (HAS-229, HAS-288); `POST /home/amx` is gone since 2.0.0 (HAS-286); asks a blinds actuator (`0B`, `POST /home/amx/eaton/blinds/{point}/status`, HAS-291) or a light actuator (`.../lights/{point}/status`, HAS-259) for its status; tells the household when the frame server is not connected for 5 min (an alert, hourly reminders, an info on the return - HAS-309); since HAS-484 a **second socket, to the panel server of the Office master** (TCP 20011, NetLinx side HAS-488, `AMX_PANEL_SERVER_HOST`) for the door panels - the entrance, and the hall since HAS-502 (two instances of one NetLinx module on the same line server, so the service still sees one client and one panel; its log lines say "entrance panel" for a press on either) - `ring`, a `ping` after a quiet minute, `gate-open` handed on inside the service; `POST /home/amx/panel/doorbell` (202, 503 `PANEL_SERVER_UNAVAILABLE`, 502 `PANEL_REFUSED`, 504 `PANEL_SERVER_TIMEOUT`), `panelServer` in the health outside the probes; the protocol pinned in `amx/CLAUDE.md`; both sockets share `LineServerClient`; since HAS-486 the outside temperature on the panel - `GET /home/weather/current` of weather-service (k8s DNS, `internal.service.weather`) every minute, `temp;<value>` on a change, `temp;` when not known, the last value to every new connection after 10 s; since HAS-487 the gate button of the panel - `gate-open` is `POST /home/gate/open?source=panel` of gate-service (k8s DNS, `internal.service.gate`), sent once, `gate;ok` on a 2xx or `409 OPEN_TOO_SOON`, `gate;failed` otherwise, one press at a time and never queued

## Releases

- **2.8.0** (2026-11-23, HAS-487: the gate button of the entrance panel
- 2.7.1, 2026-11-23, HAS-486: the outside temperature on the entrance panel
- 2.7.0 failed every read on the boolean metric `raining`, 2.7.1 reads only the temperature out of the plain JSON
- 2.6.0, 2026-11-22, HAS-484: the panel socket and the doorbell; Boot 4.1.3, cholewa-commons 1.14.0, smart-home-sdk 1.25.0
- 2.5.0, 2026-10-23, HAS-309)
