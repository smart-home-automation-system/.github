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

### Microservices

- __gateway-service__ (local-port - `6001`) 
  
[![CI](https://github.com/smart-home-automation-system/gateway-service/actions/workflows/CI.yml/badge.svg)](https://github.com/smart-home-automation-system/gateway-service/actions/workflows/CI.yml)
