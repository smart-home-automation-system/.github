# shelly-client

The library and its release history, moved out of `organization.md` (2026-11-26). What crosses into every consumer
stays in `organization.md` ("Shared libraries"); its own `CLAUDE.md` and README go deeper.

## Purpose

Models of what a Shelly answers and publishes, reactive HTTP clients (Gen2+ RPC, Gen1) and the MQTT decoder

## Consumers

aircon, blinds, energy, gate, heating, light, water, weather (2.7.0); appliance (2.2.0); boiler (2.1.0 - its clients switched off); shelly-cloud (still on 1.0.0)

## Releases

- **2.7.0** (HAS-389: `Pm1Status`, `ShellyRpcClient.pm1Status` and the `pm1` topic decoded - the meter of a PM Mini Gen3 (no temperature, no power factor), for the plug of the air conditioner of sanctum, HAS-390
- 2.6.0, HAS-404: `ShellyGen1Client.relay` with a timer in seconds, for the circulation pump
- 2.5.0, HAS-315: the virtual components of a Shelly X device - `NumberStatus`, `BooleanStatus`, `ObjectStatus` and the `number` / `boolean` / `object` topics (no id in their status, judged by `last_update_ts`), `attrs` of `ShellyComponent`, `ShellyRpcClient.booleanSet`, for the water valve of HAS-316
- 2.4.0, HAS-367: the add-on sensors of a Gen1 Shelly 1 - `ext_temperature`, `ext_humidity`, `ext_sensors` of `Gen1DeviceStatus`, for the sauna thermometer of HAS-366
- 2.3.0, HAS-327: `EmStatus`, `EmDataStatus`, `ShellyRpcClient.emStatus` / `emDataStatus`, the `em` / `emdata` topics
- 2.2.0, HAS-278: `Gen1Meter`, `ShellyGen1Client.meter`)
