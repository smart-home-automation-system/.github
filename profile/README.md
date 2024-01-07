## Smart Home Automation System

It's a microservice application which controls smart home.

Spring Boot microservice are using

![Java](https://img.shields.io/badge/java-17-yellow?style=plastic)
![SpringBoot](https://img.shields.io/badge/SpringBoot-3.2.1-blue?style=plastic)

SpringBoot services are communicating with home system automations like:
- AMX control system - 2way communication with devices connected to AMX
  - Eaton wireless devices
    - temperature sensors
- Shelly Wi-Fi devices by REST API

## Microservices

- __[gateway-service](https://github.com/smart-home-automation-system/gateway-service)__ (local-port - `6001`) 
  
[![CI](https://github.com/smart-home-automation-system/gateway-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/gateway-service/actions/workflows/CI.yml)
![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/gateway-service?style=plastic)


## Libraries
- __[eaton-utility](https://github.com/smart-home-automation-system/eaton-utility)__

[![CI](https://github.com/magikabdul/cholewa-commons/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/eaton-utility/actions/workflows/CI.yml)
![GitHub Release](https://img.shields.io/github/v/release/smart-home-automation-system/eaton-utility?style=plastic)
![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/smart-home-automation-system/eaton-utility?style=plastic)
![GitHub top language](https://img.shields.io/github/languages/top/smart-home-automation-system/eaton-utility?style=plastic)
