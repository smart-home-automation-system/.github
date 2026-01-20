## Smart Home Automation System

It's a microservice application that controls a smart home.

Spring Boot microservices are using

![Java](https://img.shields.io/badge/java-17-yellow?style=plastic)
![SpringBoot](https://img.shields.io/badge/SpringBoot-4.0.1-blue?style=plastic)

SpringBoot services are communicating with home system automations like:

- AMX control system – 2way communication with devices connected to AMX
    - Eaton wireless devices
        - temperature sensors
- Shelly Wi-Fi devices by REST API

## Microservices

- __[gateway-service](https://github.com/smart-home-automation-system/gateway-service)__ (local-port - `6001`)

  [![CI](https://github.com/smart-home-automation-system/gateway-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/gateway-service/actions/workflows/CI.yml)
  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=smart-home-automation-system_gateway-service&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=smart-home-automation-system_gateway-service)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/gateway-service?style=plastic)
  ![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/gateway-service?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/gateway-service?style=plastic)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/gateway-service?style=plastic)

- __[heating-service](https://github.com/smart-home-automation-system/heating-service)__ (local-port - `6002`)

  [![CI](https://github.com/smart-home-automation-system/heating-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/heating-service/actions/workflows/CI.yml)
  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=smart-home-automation-system_heating-service&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=smart-home-automation-system_heating-service)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/heating-service?style=plastic)
  ![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/heating-service?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/heating-service?style=plastic)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/heating-service?style=plastic)

- __[notification-service](https://github.com/smart-home-automation-system/notification-service)__ (local-port - `6003`)

  [![CI](https://github.com/smart-home-automation-system/notification-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/notification-service/actions/workflows/CI.yml)
  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=smart-home-automation-system_notification-service&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=smart-home-automation-system_notification-service)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/notification-service?style=plastic)
  ![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/notification-service?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/notification-service?style=plastic)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/notification-service?style=plastic)

- __[ai-service](https://github.com/smart-home-automation-system/ai-service)__ (local-port - `6004`)

  [![CI](https://github.com/smart-home-automation-system/ai-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/ai-service/actions/workflows/CI.yml)
  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=smart-home-automation-system_ai-service&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=smart-home-automation-system_ai-service)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/ai-service?style=plastic)
  ![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/ai-service?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/ai-service?style=plastic)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/ai-service?style=plastic)

- __[database-service](https://github.com/smart-home-automation-system/database-service)__ (local-port - `6005`)

  [![CI](https://github.com/smart-home-automation-system/database-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/database-service/actions/workflows/CI.yml)
  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=smart-home-automation-system_database-service&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=smart-home-automation-system_database-service)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/database-service?style=plastic)
  ![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/database-service?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/database-service?style=plastic)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/database-service?style=plastic)

- __[water-service](https://github.com/smart-home-automation-system/water-service)__ (local-port - `6006`)

  [![CI](https://github.com/smart-home-automation-system/water-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/water-service/actions/workflows/CI.yml)
  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=smart-home-automation-system_water-service&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=smart-home-automation-system_water-service)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/water-service?style=plastic)
  ![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/water-service?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/water-service?style=plastic)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/water-service?style=plastic)

- __[boiler-service](https://github.com/smart-home-automation-system/boiler-service)__ (local-port - `6007`)

  [![CI](https://github.com/smart-home-automation-system/boiler-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/boiler-service/actions/workflows/CI.yml)
  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=smart-home-automation-system_boiler-service&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=smart-home-automation-system_boiler-service)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/boiler-service?style=plastic)
  ![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/boiler-service?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/boiler-service?style=plastic)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/boiler-service?style=plastic)

## Libraries

- __[eaton-utility](https://github.com/smart-home-automation-system/eaton-utility)__

  [![CI](https://github.com/smart-home-automation-system/eaton-utility/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/eaton-utility/actions/workflows/CI.yml)
  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=smart-home-automation-system_eaton-utility&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=smart-home-automation-system_eaton-utility)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/eaton-utility?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/eaton-utility?style=plastic)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/eaton-utility?style=plastic)

- __[shelly-client](https://github.com/smart-home-automation-system/shelly-client)__

  [![CI](https://github.com/smart-home-automation-system/shelly-client/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/shelly-client/actions/workflows/CI.yml)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/shelly-client?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/shelly-client?style=plastic)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/shelly-client?style=plastic)

- __[discord-client](https://github.com/smart-home-automation-system/discord-client)__

  [![CI](https://github.com/smart-home-automation-system/discord-client/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/discord-client/actions/workflows/CI.yml)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/discord-client?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/discord-client?style=plastic)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/discord-client?style=plastic)

- __[smart-home-sdk](https://github.com/smart-home-automation-system/smart-home-sdk)__

  [![CI](https://github.com/smart-home-automation-system/smart-home-sdk/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/smart-home-sdk/actions/workflows/CI.yml)
  ![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/smart-home-sdk?style=plastic)
  ![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/smart-home-sdk?style=plastic)
  ![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/smart-home-sdk?style=plastic)
