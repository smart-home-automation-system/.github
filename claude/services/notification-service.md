# notification-service

What this service does and its release history, moved out of `organization.md` (2026-11-26) - the detail a task
on this service, or on a service that talks to it, reads first. Its own `CLAUDE.md` and README go deeper. Local port 6003.

## Depends on - read also

- Calls over HTTP: `database-service`, `presence-service`.
- Called by: no service (and the dashboard through the gateway).
- Broker: consumes the `alert`, `info` and `household` queues of `/notification` - every publisher of the table below reaches the household through it.
- **Before a change that touches what crosses these lines, read their files too**: `database-service.md`, `presence-service.md` - and the contracts in `../organization.md`.

## What it does

Consumes the `alert` and `info` queues and posts each message to the Discord channel `alerts` as an embed coloured by its level — one listener container per queue on purpose (HAS-179);

since 0.5.0 the `household` queue: the JSON `HouseholdNotification` worded in Polish (`HouseholdMessages`) and delivered by every transport at once (`HouseholdDispatcher`): the Discord household channel, **Web Push** since 0.6.0 (HAS-276: the members at home by presence-service, their browsers from database-service, RFC 8291 / 8292 with the JDK, only the push services of `household.push.allowed-hosts`, 404/410 removes the subscription, no `Topic` header - Apple refuses it; manifest `push-subject`, `vapid-*`) and **SMS** since 0.7.0 (HAS-275: SMSAPI, sender `smart-home`, one SMS per member at home with a phone, the registry read from `GET /home/household`, the Discord footer names who was texted); `requireInteraction` keeps a push on the screen until clicked (0.7.1); the washing machine, the dryer and the dishwasher by their Polish names (0.7.2, HAS-285); the acknowledgement names who emptied it (`member`, 0.7.3, HAS-347); `GET /skippy?category=household` is its smoke test, Discord only, `&sms=true` also texts the administrators;

since 0.8.0 an alert or info marked `sms: true` is texted to the administrators with a phone after the Discord post, also when Discord failed (HAS-335, smoke test `GET /skippy?message=&sms=true`);

since 0.9.0 the pending household requests of `database-service` >= 0.22.0 texted to their recipients at 08:00 of the house (`household.requests.*`, at home or not, marked sent after each accepted SMS, the rest of a long list `i jeszcze N` for the next day), the first `@Scheduled` task of the service; `POST /home/notification/requests/send` runs the pass by hand, not routed (HAS-410);

since 0.10.0 the reminders and the announcements of those requests (HAS-416, database-service >= 0.24.0): every minute the requests ticked off told to their authors, at 20:00 of the house one reminder per recipient of the open texted requests not reminded today, then the authors of the requests open 3 days after their SMS - each by Web Push to that member's browsers at home or not, an SMS only without a browser, only what a delivered message carried marked (`POST /requests/announce`, `/requests/remind` by hand, not routed)

## Releases

- **0.16.0** (2026-11-28, HAS-522, epic HAS-520): the three events of load shedding of smart-home-sdk 1.27.0 worded - `load shedding started` (`Praca na baterii`, orange: the grid lost, the warning about the hob and the oven first so a 160-character SMS keeps it, then `Wyłączone: <devices>`), `load shedding device running` (amber, `Wciąż pracuje / pracują: <devices>`), `load shedding over` (`Prąd z sieci wrócił`, green, `Urządzenia znów włączone: <devices>`); the subject is the SOLAX inverter, the loads come in `devices` as energy-service names them. The start and a load still at work texted to the members at home (title first, one rule `SmsText.of` shared with the smoke test), the end never; all three pushed to the members at home under the tag `load-shedding-<deviceId>`, the end silently. Smoke test `event=load shedding started|load shedding device running|load shedding over` (`sms=true` refused for the end). Must run before energy-service publishes the events (HAS-525), which should send the loads still at work in one event - one SMS per event. Smoke-tested on the cluster 2026-11-28 (three posts, one SMS of the start)
- 0.15.1, 2026-11-25, HAS-498: a gate opened from a wall panel worded - `Brama otwarta z panelu ściennego.`, one source for the entrance and the hall panel; Spring Boot 4.2.0, cholewa-commons 2.0.0
- 0.15.0, 2026-11-22, HAS-481: a gate opened from the entrance panel worded - `Brama otwarta z panelu w wejściu.`, still never pushed nor texted; the smoke test `event=gate opened` takes `source=`; smart-home-sdk 1.25.0
- 0.14.0, 2026-11-20, HAS-462: the fire alarm of smart-home-sdk 1.24.0 worded in Polish on the household channel (Alarm pożarowy, the detector and its room in Polish), texted to every member with a phone and pushed to every switched-on member, at home or not - the end too; a room the SDK of the service does not know read as no room, never a dropped alarm; smoke test `event=fire alarm` / `fire alarm over`; Boot 4.1.3
- 0.13.0, 2026-11-18, HAS-472: a garage gate left open worded in Polish on the intercom channel (Brama garażowa <name>, how long open, the temperature of the cold alarm), pushed to every switched-on member - closed never - and the first message of an alarm texted to the members of `household.garage.sms-members` (manifest `garage-sms-members`), at home or not; smoke test `event=garage`; smart-home-sdk 1.23.0
- 0.12.0, 2026-11-18, HAS-451: the doorbell and the gate worded in Polish (Domofon / Brama) on an intercom Discord channel of their own (`discord_intercom_channel_id`), a ring pushed to every switched-on member at home or not, the opening never pushed, neither ever texted; smart-home-sdk 1.22.0
- 0.11.1, 2026-11-12, HAS-430: a transport that does not carry an event is skipped by the dispatcher and logged as not carried - the smog no longer logged as delivered by [sms]
- 0.11.0, HAS-430: the smog warning / smog over of weather-service worded in Polish (PM10 / PM2.5, very bad by the GIOS index), on Discord and by Web Push, **never by SMS**; GET /skippy?category=household&event=smog
- 0.10.0, 2026-11-10, HAS-416: the evening reminders and the announcements to the authors
- 0.9.0, 2026-11-06, HAS-410: the household requests by SMS at 08:00
- 0.8.0, HAS-335: marked alerts and infos by SMS
- 0.7.3, HAS-347: "potwierdza Liwia")
