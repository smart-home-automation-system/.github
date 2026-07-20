# Smart Home Automation System — organization context

Solo-developer project: a set of repositories under the GitHub organization
[smart-home-automation-system](https://github.com/smart-home-automation-system) that together
control a real smart home — an AMX/NetLinx control system with Eaton wireless devices, and
Shelly Wi-Fi devices. The backend runs on a Kubernetes cluster. All repositories are public
except `deployment-tools`.

## Repository map

### Spring Boot microservices (all reactive — WebFlux)

| Repository | Local port | Purpose |
|---|---|---|
| `service-discovery` | 6000 | Eureka server |
| `api-gateway-service` | 6200 | Spring Cloud Gateway — the **only** entry point into the cluster from outside (k8s ingress routes here) |
| `gateway-service` | 6001 | Bridge to the AMX control system (2-way communication with AMX-connected devices) — **to be renamed `amx-service`** |
| `heating-service` | 6002 | Heating control |
| `notification-service` | 6003 | Notifications (Discord bot) |
| `ai-service` | 6004 | AI integration |
| `database-service` | 6005 | Persistence facade for other services |
| `water-service` | 6006 | Water control |
| `boiler-service` | 6007 | Boiler control |
| `shelly-cloud-service` | — | Shelly cloud integration |

Do not confuse `api-gateway-service` (HTTP edge / Spring Cloud Gateway) with
`gateway-service` (AMX hardware bridge).

### Shared libraries (Maven, `cloud.cholewa` group)

| Library | Purpose | Current consumers |
|---|---|---|
| `cholewa-commons` | Common utilities | api-gateway, boiler, database, gateway, heating, shelly-cloud, water |
| `smart-home-sdk` | Shared domain / API models | boiler, database, gateway, heating, shelly-cloud, water |
| `shelly-client` | REST client for Shelly devices | boiler, heating, shelly-cloud, water |
| `eaton-utility` | Eaton device helpers | gateway-service only — **to be merged into gateway-service** |
| `cholewa-security` | Security/auth | none yet — kept for possible future auth in `api-gateway-service` |

### Other repositories

- `amx` — AMX/NetLinx sources for the physical control system (not Java).
- `web-application` — Angular frontend; being (re)built completely from scratch.
- `deployment-tools` — **PRIVATE**: Kubernetes manifests, local `kind` cluster setup,
  pipelines, RabbitMQ config. Private infrastructure details belong here, never in
  public repos.
- `organization-repository` — local clone of the org's `.github` repo: organization
  profile README and this shared Claude configuration (`claude/`).

## Architecture notes

- Reactive stack everywhere: Spring WebFlux, no blocking calls in service code.
- Async messaging via RabbitMQ: `gateway-service`, `heating-service`, `notification-service`.
- Service discovery: Kubernetes-native (k8s Services + DNS). Eureka
  (`service-discovery`) is being phased out — see Pending architecture changes.
- External traffic: k8s → `api-gateway-service` → internal services.

## Pending architecture changes (decided 2026-07, executed by the user)

- `discord-client` — repository will be removed (no consumers; `notification-service`
  has its own Discord implementation).
- `eaton-utility` — will be merged into `gateway-service` (its only consumer), then the
  library repo retired.
- `service-discovery` (Eureka) — will be removed: k8s DNS covers discovery. This implies
  removing the `spring-cloud-starter-netflix-eureka-client` dependency and config from
  `api-gateway-service`, `boiler-service`, `shelly-cloud-service` and `water-service`,
  and replacing the discovery locator in `api-gateway-service` with explicit static
  routes using k8s DNS names.
- `cholewa-security` — stays; possible future use for auth in `api-gateway-service`.
- `gateway-service` — will be renamed to **`amx-service`** (removes the confusion with
  `api-gateway-service`; consistent with domain-based service naming). The rename happens
  after `eaton-utility` is merged in. Affected places: GitHub repo name, Maven
  artifactId/`spring.application.name`, Docker Hub image name, k8s manifests in
  `deployment-tools`, org profile README badges/links.

## Conventions

- Java 17, Spring Boot 4.0.1 (`spring-boot-starter-parent`), Maven, groupId `cloud.cholewa`.
- Libraries are consumed from GitHub Packages
  (`https://maven.pkg.github.com/smart-home-automation-system/*`).
- CI/CD — GitHub Actions in every repo:
  - `CI.yml` — build + tests on push/PR.
  - `sonar.yml` — SonarCloud analysis.
  - Services: `release.yml` — release builds a Docker image pushed to Docker Hub.
  - Libraries: `package.yml` — release publishes the artifact to GitHub Packages.
- A new microservice mirrors the structure and workflows of `water-service`
  (the reference service) until a dedicated scaffolding skill exists.

## Working rules for Claude

- **Spring Boot services and libraries**: the user writes the code themselves. Do NOT write
  or modify code there unless explicitly asked. Default contributions: analysis, code
  review, security review, answering questions.
- **`web-application`**: full autonomy — Claude designs and implements the frontend.
- **`amx`**: NetLinx language; analysis and suggestions, ask before modifying.
- Never commit or push unless explicitly asked.
- All repos except `deployment-tools` are public: never put secrets, tokens, IP addresses,
  or private infrastructure details into files of public repos.
