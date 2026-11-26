# smart-home-sdk

The library and its release history, moved out of `organization.md` (2026-11-26). What crosses into every consumer
stays in `organization.md` ("Shared libraries"); its own `CLAUDE.md` and README go deeper.

## Purpose

Shared domain / API models (household, device registry, calendar, device events)

## Consumers

aircon, amx, appliance, blinds, boiler, database, energy, gate, heating, light, notification, presence, safety, shelly-cloud, water, weather

## Releases

- **1.25.0** (HAS-480: `GateOpenSource.panel` - the entrance panel at the door as a third way to open the driveway gate, epic HAS-479; `fromValue` throws on a value it does not know, so notification-service (HAS-481) reads it before gate-service publishes it (HAS-483)
- 1.24.0, HAS-456: `DeviceKind` smoke detector / co detector / heat detector at once, `SmartVendor.xsense` with `XsenseBinding` (the serial of the base station, the id it gives a detector), `HouseholdEvent` fire alarm / fire alarm over and the optional `HouseholdNotification.room` - database-service (HAS-457) and the dashboard (HAS-458) move first, notification-service (HAS-462) reads the events before safety-service publishes (HAS-461)
- 1.23.0, HAS-470: `HouseholdEvent` garage gate open cold / open empty house / open long / closed, the optional `HouseholdNotification.openSince` / `temperature`, `openingSensors` allowed for a `gate` - notification-service (HAS-472) reads the events before gate-service publishes them (HAS-475), database-service (HAS-471) and the dashboard accept the sensors of a gate before one is stored
- 1.22.0, HAS-445: `DeviceKind.intercom` / `gate`, `HikvisionBinding` (address, serial number), `SmartVendor.hikvision`, `HouseholdEvent` doorbell ringing / gate opened and the optional `HouseholdNotification.source` (`GateOpenSource`: screen, dashboard) - database-service and the dashboard move first, notification-service (HAS-451) reads the events before gate-service publishes
- 1.21.0, HAS-429: `HouseholdEvent` smog warning / smog over and the optional `HouseholdNotification.pm10` / `pm25` - weather-service publishes, notification-service (HAS-430) must read them first
- 1.20.0, HAS-424: `DeviceKind.air quality sensor`, `BleboxBinding` (address, deviceId), `SmartVendor.blebox` - database-service and the dashboard move first
- 1.19.0, HAS-414: `MemberRequest` gains three optional server marks - `remindedAt`, `doneAnnouncedAt`, `staleAnnouncedAt` - for the evening reminders of notification-service and what the author of a request was told, database-service moves first
- 1.18.0, HAS-377: `DeviceKind.air conditioner`, `GreeBinding` (address, MAC), `SmartVendor.gree` - database-service and the dashboard move first
- 1.17.0, HAS-408: `MemberRequest`, the errand of one member for another - a model of its own, never a field of `HouseholdMember`
- 1.16.0, HAS-311: `DeviceKind.water valve`
- 1.15.0, HAS-326: `DeviceKind.inverter`, `InverterBinding`, `InverterBrand`
- 1.14.0, HAS-347: `HouseholdNotification.member`
- 1.13.0, HAS-271: `DeviceKind.appliance` with `ApplianceSettings`, `HouseholdNotification`, `PushSubscription`)
