# appliance-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6013.

## Depends on - read also

- Calls over HTTP: `database-service`, `presence-service`.
- Called by: `api-gateway-service` (and the dashboard through the gateway).
- Broker: publishes `household` and alerts to `/notification`.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `presence-service.md` - and the contracts in `../organization.md`.

## What it does

Appliance monitoring (epic HAS-270): the cycles of the washing machine, the dryer and the dishwasher read from the power draw of their Shelly plugs (Gen1, polled), the household told when one finished and reminded until it acknowledges - the `household` category of notification-service, `NotificationPublisher.publishHousehold` of cholewa-commons 1.12.0. The appliances are the kind `appliance` of the device registry (database-service 0.18.0).

Since HAS-278: the appliances of the registry every 5 min, each Gen1 plug read every 30 s (`ShellyGen1Client.meter`), the cycle detected by a pure `CycleDetector` (a minute above `runningAboveWatts` starts it, `minRunMinutes` checked at its end, an invalid sample keeps the state), `appliance_run` and `appliance_sample` (14 days), `GET /home/appliance`, `/{id}`, `/{id}/runs`, `/{id}/samples` (`NOT_FOUND_APPLIANCE`); since HAS-279 the household told - `appliance finished` within a minute of the end (quiet hours or not), a reminder every `reminderEveryMinutes` at most `maxReminders` outside the quiet hours, `POST /home/appliance/{id}/acknowledge` (204, `appliance acknowledged`; 409 `NOTHING_TO_ACKNOWLEDGE`), V3 `notified_at` / `last_message_at`; since HAS-347 `?member=` - checked against the household profiles (`400 UNKNOWN_MEMBER`), stored in `acknowledged_by` (V4) and sent as `HouseholdNotification.member`; one broker connection to `/notification` (user `notification`), own database `home-automation-appliance` (pool 2), `Recreate`, never scaled. Routes HAS-281; since HAS-280 a plug without a reading for 5 min is an alert on the technical channel (one per check naming every plug, a reminder every hour, an info on the return; in memory, as in boiler-service); since HAS-343 the NTAG 424 DNA tags on the appliances (key `appliance.nfc.key`, tags by UID in the manifest, programmed per `docs/nfc-tag-programming.pdf` of deployment-tools); since HAS-344 every cycle is attributed - a tag read and "Emptied" in the application with a member are equal confirmations (owner 2026-10-30), a second member within 10 min shares it, a mute is unattributed - with who was at home at its finish and completion, read from presence-service (`/home/presence/residents/presence` over k8s DNS, never blocking)

## Releases

- **0.10.0** (2026-11-26, HAS-512: the household profiles read with the permission `amplifier_unlock` (SDK 1.26.0, epic HAS-508); Spring Boot 4.2.0, cholewa-commons 2.0.0, shelly-client 2.7.0, `spring-boot-starter-rabbitmq`)
- 0.9.0 (2026-10-30, HAS-345: `GET /home/appliance/reports/members` - the chores per member against the cycles finished while at home, one SQL aggregation
- 0.8.0, HAS-344: the attribution and the presence snapshots, V6
- 0.7.0, HAS-343: a chore claimed with the NFC tag of the appliance - `POST /home/appliance/claims`, NTAG 424 DNA SUN encrypted, V5
- 0.6.0, HAS-280: the availability monitor of the plugs
- 0.5.1, HAS-348: acknowledged while finishing, a short cycle too - ended at the fall, only `appliance acknowledged`
- 0.4.0, HAS-347: who acknowledged it
- 0.3.1, HAS-285: the dryer's anti-crease turns)
