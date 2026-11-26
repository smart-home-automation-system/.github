# cholewa-commons

The library and its release history, moved out of `organization.md` (2026-11-26). What crosses into every consumer
stays in `organization.md` ("Shared libraries"); its own `CLAUDE.md` and README go deeper.

## Purpose

Common utilities: the error contract, the pooled R2DBC factory, English validation messages, the RabbitMQ connection name, `NotificationPublisher`, the required properties checked at the start (`cholewa.required-properties`, 1.9.0), the processor of a coded domain error (`DomainExceptionProcessor`, 1.14.0, HAS-213), Logbook in the reactive chain so that its lines carry the trace (1.10.0, HAS-298), the actuator left out of its log (1.10.1), a pool for the scheduler by default and `ScheduledPass.bounded` for every reactive `@Scheduled` pass (1.11.0, HAS-300)

## Consumers

ai, aircon, amx, api-gateway, appliance, blinds, boiler, database, energy, gate, heating, light, notification, presence, safety, shelly-cloud, water, weather

## Releases

- **2.0.0** (HAS-494: Spring Boot 4.2.0 - the classic RabbitMQ from `spring-boot-rabbitmq` and `org.springframework.boot.rabbitmq.autoconfigure`; **breaking** for a consumer with a broker, see below
- 1.14.0, HAS-213: `DomainExceptionProcessor(status, ErrorId)` - the processor of a coded domain error, moved from database-service, adopted in HAS-214 / HAS-215
- 1.13.0, HAS-335: `publishAlertSms` / `publishReminderSms` / `publishInfoSms`, the header `sms`
- 1.12.0, HAS-277: `publishHousehold(json)`, the household category with a JSON body)
