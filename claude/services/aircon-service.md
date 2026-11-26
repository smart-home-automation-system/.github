# aircon-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6015.

## Depends on - read also

- Calls over HTTP: `database-service`, `heating-service`, `presence-service`, `energy-service`.
- Called by: `api-gateway-service`, `safety-service` (and the dashboard through the gateway).
- Broker: alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `heating-service.md`, `presence-service.md`, `energy-service.md`, `safety-service.md` - and the contracts in `../organization.md`.

## What it does

The air conditioners of the house (epic HAS-376): five Gree indoor units over their local protocol - no Gree cloud.

Since HAS-380 the units of the registry (`?kind=air conditioner&enabled=true` every 5 min, `GreeBinding`) and the Gree LAN driver: unicast UDP 7000 to the address of the registry (a broadcast from the cluster does not reach VLAN 30 - verified from the pod on 2026-11-07), the scan with the V1 cipher only to confirm the MAC, bind / status / cmd with V2 (AES-128-GCM); **the key of a unit in memory only**, never stored nor logged; since HAS-381 the state of every unit read every 30 s, one after the other (`aircon_state` the current row, `aircon_state_change` the changes with who made them - V2), restored at a start; `GET /home/aircon`, `/{id}`, `/rooms/{room}` answer the state kept, a field not known left out (`REGISTRY_UNAVAILABLE`, `NOT_FOUND_AIRCON`, `NOT_FOUND_ROOM`); since HAS-382 the commands `POST /home/aircon/{id}` and `/rooms/{room}` (`source` dashboard, rule, window, empty-house, grid-outage), confirmed by a read 2 s later (`lastCommandConfirmed`), `CommandRules` copied by the dashboard (cooling never below 22 C, 16-30 C), and the guard raising cooling below 22 C set with the remote back to 22 C in the same pass (`minimum-restored`, V3). Own database `home-automation-aircon` (pool 2, `V1` empty); since HAS-383 a unit that does not answer for 5 min is an alert on the technical channel (one per pass naming every unit, a reminder hourly, an info on the return; open alerts in `aircon_availability_alert`, V4; `unreachableSince` in the reads) - one broker connection to `/notification` (user `notification`); since HAS-384 the open windows: `GET /home/heating/rooms` of heating-service (>= 1.20.0, k8s DNS) every minute - a window that holds there stops a unit that is on (`source=window`, its state kept in `aircon_window_hold`, V5), the windows closed within an hour set it back, a change of the remote or the dashboard gives it up; `window` in the reads; since HAS-385 the empty house and a lost grid: `GET /home/presence/residents/presence` and `GET /home/energy/status` (>= 0.4.0) every minute over k8s DNS - nobody at home for 10 min switches off the cooling units outside sanctum (`source=empty-house`), the grid lost every unit that is on (`source=grid-outage`), once per episode (`aircon_automation_episode`), nothing switched back on; every automatic command in `aircon_rule_run` (V6); `GET /home/aircon/automation`; the presence client the fourth copy (owner 2026-11-07); since HAS-386 a rule per unit (`aircon_rule`, V7; `GET /rules`, `GET` / `PUT` / `DELETE /{id}/rules`, `RuleRules` copied by the dashboard, `INVALID_RULE` / `NOT_FOUND_RULE`): keep the room below a threshold by the `temperature` of `GET /home/heating/rooms` (not older than 3 h, never the sensor of the unit), cooling at the target, off below the hysteresis only what it switched on, never within 30 min of a change of a person; since HAS-387 `heatBySchedule` is a frost protection (owner 2026-11-08: the comfort is switched on by hand) - the room more than 1 C below what its schedule asks for (`scheduledTemperature` of `GET /home/heating/rooms`, sanctum 9 C) switches the unit on in heat with the target it has, the schedule reached switches off a heating the rule switched on after 30 min at least, a unit it switched off rests 10 min; the house switch is not read (0.8.0 read it and heated from 16 C); keep below wins; since HAS-390 the two plugs that feed the units read every 30 s through shelly-client 2.7.0 (the Plus Plug S of the four indoor units, the PM Mini Gen3 of sanctum; not registry devices, their addresses in the manifest) - `aircon_power_sample` / `aircon_power_day` (V8), `GET /home/aircon/power`, `/power/samples` (`HistoryRange` the fifth copy, owner 2026-11-08), `compressorRunning` in the reads, and the manual power cycle of the indoor plug `GET` / `POST /power-cycle` - refused while an indoor unit is known on or the plug draws above 20 W, an alert when it stays off (`aircon_power_cycle`); since HAS-391 the run hours of every unit from `aircon_state_change` since its cleaning (`aircon_filter`, V9), `filter` in the reads, an info on Discord at 200 h and every 50 h more, `POST /{id}/filter-cleaned`, `GET /{id}/runs`; `Recreate`, never scaled. The five units are registered since 2026-11-07 (HAS-393, ids 140-144, listed in `deployment-tools/scripts/gree/devices.md`), each read live from the pod

## Releases

- **0.12.0** (2026-11-22, HAS-467: the command source `safety` - safety-service switching the units off at a fire alarm, logged in `aircon_rule_run`, the rule held off for `manual-hold` after it as after a person, V10; Boot 4.1.3, cholewa-commons 1.14.0, smart-home-sdk 1.24.0
- 0.11.0, 2026-11-08, HAS-391: the run hours and the filter reminder
- 0.10.0, HAS-390: the power draw of the plugs and the manual power cycle
- 0.9.0, HAS-387: heat by schedule as a frost protection
- 0.8.0, HAS-387: heat by the heating schedule of the room
- 0.7.0, HAS-386: a rule per unit - keep the room below a temperature
- 0.6.0, HAS-385: the empty house and a lost grid
- 0.5.0, HAS-384: the open windows, read from heating-service
- 0.4.0, HAS-383: the availability monitor
- 0.3.0, HAS-382: the commands with the 22 C minimum and the guard against the remote
- 0.2.0, HAS-381: the state of every unit read every 30 s and stored
- 0.1.0, HAS-380: the scaffold, the registry and the Gree LAN driver)
