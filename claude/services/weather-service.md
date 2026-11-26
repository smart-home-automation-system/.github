# weather-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6010.

## Depends on - read also

- Calls over HTTP: `database-service`.
- Called by: `api-gateway-service`, `amx-service`, `blinds-service`, `energy-service`, `gate-service` (and the dashboard through the gateway).
- Broker: consumes `device.prod.weather`; alerts and the smog (`household`) to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `amx-service.md`, `blinds-service.md`, `energy-service.md`, `gate-service.md` - and the contracts in `../organization.md`.

## What it does

The weather station (epic HAS-233): a Shelly WS90 read locally through a BTHome gateway, the readings kept and served to the dashboard, the blinds schedules and the overview. The station is adopted by the Plug S Gen3 TREADMILL (HAS-234; registry: gateway 54, station 55). Takes in the readings (HAS-236): the station and its gateway from the registry, which `bthomesensor` is which metric from the gateway (`Shelly.GetComponents`), the current state in memory from the status topics (13 metrics, each published only on a change) and from the read of the gateway, a snapshot a minute into `weather_reading` of its own database `home-automation-weather` (after a change only). Reconciles with the gateway every 5 min and watches it (HAS-237): no reading from the station or no answer from the gateway for 30 min is an alert, a reminder every hour, one info when over; open alerts in `station_alert`. Read API (HAS-238): `GET /home/weather/current` (per metric value, measuredAt, stale), `/status` (gateway reachable, last reading, silent), `/history?metric=&from=&to=` (the rules of the hot-water history, avg/min/max, `UNKNOWN_METRIC`); readings kept 730 days. `Recreate`, never scaled. Routed as a GET allowlist (gateway 0.6.0, HAS-239)

## Releases

- **0.8.0** (2026-11-13, HAS-437: the run time of the laser of the air quality sensor - `GET /api/air/runtime` once an hour, a warning on the technical channel at `weather.air.laser.warn-at-hours` (7000 h of the about 8000 of its life) and every 500 h more, an info when the counter drops (a replaced sensor), no SMS; `air_sensor_runtime` (V5) on a change only; `/status` airSensor.laser {hours, readAt, lifeHours, warn}
- 0.7.1, 2026-11-12, HAS-429: the air quality sensor watched on the technical channel (no valid reading for weather.air.silent-after, station_alert AIR_SENSOR) and the smog told to the household - smog warning / smog over of SDK 1.21.0, episodes in air_quality_alert (V4), no SMS; /status airSensor.silent and smog
- 0.7.1 judges a gap of the measurements by silent-after (0.7.0 by smog-after opened nothing below the cycle of the sensor)
- 0.6.0, 2026-11-12, HAS-428: the air quality stored on the rows of weather_reading (V3: pm1, pm25, pm10, air_quality_level) and served by /history
- 0.5.0, 2026-11-12, HAS-427: the BleBox airSensor outside the house (registry 145) read every minute over HTTP - `GET /api/air/state`, never `/s/kick` - pm1, pm25, pm10 and airQualityLevel in `/current`, `airSensor` in `/status`, held apart from the station, not stored before HAS-428; cholewa-commons 1.14.0, SDK 1.20.0, shelly-client 2.7.0
- 0.4.1, 2026-10-23, HAS-304: every scheduled task bounded, cholewa-commons 1.11.0)
