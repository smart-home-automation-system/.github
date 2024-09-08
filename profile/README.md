## Smart Home Automation System

It's a microservice application which controls smart home.

Spring Boot microservice are using

![Java](https://img.shields.io/badge/java-17-yellow?style=plastic)
![SpringBoot](https://img.shields.io/badge/SpringBoot-3.3.3-blue?style=plastic)

SpringBoot services are communicating with home system automations like:
- AMX control system - 2way communication with devices connected to AMX
  - Eaton wireless devices
    - temperature sensors
- Shelly Wi-Fi devices by REST API

## Microservices

- __[gateway-service](https://github.com/smart-home-automation-system/gateway-service)__ (local-port - `6001`)

    [![CI](https://github.com/smart-home-automation-system/gateway-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/gateway-service/actions/workflows/CI.yml)
![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/gateway-service?style=plastic)
![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/gateway-service?style=plastic)
![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/gateway-service?style=plastic)
![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/gateway-service?style=plastic)

- __[heating-service](https://github.com/smart-home-automation-system/heating-service)__ (local-port - `6002`)

    [![CI](https://github.com/smart-home-automation-system/heating-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/heating-service/actions/workflows/CI.yml)
![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/heating-service?style=plastic)
![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/heating-service?style=plastic)
![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/heating-service?style=plastic)
![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/heating-service?style=plastic)

- __[notification-service](https://github.com/smart-home-automation-system/notification-service)__ (local-port - `6003`)

    [![CI](https://github.com/smart-home-automation-system/notification-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/notification-service/actions/workflows/CI.yml)
![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/notification-service?style=plastic)
![GitHub last commit](https://img.shields.io/github/last-commit/smart-home-automation-system/notification-service?style=plastic)
![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/notification-service?style=plastic)
![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/notification-service?style=plastic)

## Libraries
- __[eaton-utility](https://github.com/smart-home-automation-system/eaton-utility)__

    [![CI](https://github.com/smart-home-automation-system/eaton-utility/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/eaton-utility/actions/workflows/CI.yml)
![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/eaton-utility?style=plastic)
![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/eaton-utility?style=plastic)
![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/eaton-utility?style=plastic)

- __[shelly-client](https://github.com/smart-home-automation-system/shelly-client)__

    [![CI](https://github.com/smart-home-automation-system/shelly-client/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/shelly-client/actions/workflows/CI.yml)
![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/shelly-client?style=plastic)
![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/shelly-client?style=plastic)
![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/shelly-client?style=plastic)