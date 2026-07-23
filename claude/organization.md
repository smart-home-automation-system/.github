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
| `amx-service` | 6001 | Bridge to the AMX control system (2-way communication with AMX-connected devices) |
| `heating-service` | 6002 | Heating control |
| `notification-service` | 6003 | Notifications (Discord bot) |
| `ai-service` | 6004 | AI integration |
| `database-service` | 6005 | Persistence facade for other services |
| `water-service` | 6006 | Water control |
| `boiler-service` | 6007 | Boiler control |
| `shelly-cloud-service` | — | Shelly cloud integration — **unfinished, local-only** (not a git repo, no GitHub repo yet; kept as is for now) |

Do not confuse `api-gateway-service` (HTTP edge / Spring Cloud Gateway) with
`amx-service` (AMX hardware bridge).

### Shared libraries (Maven, `cloud.cholewa` group)

| Library | Purpose | Current consumers |
|---|---|---|
| `cholewa-commons` | Common utilities | amx, api-gateway, boiler, database, heating, shelly-cloud, water |
| `cholewa-security` | Security/auth | none yet — kept for possible future auth in `api-gateway-service` |
| `smart-home-sdk` | Shared domain / API models | amx, boiler, database, heating, shelly-cloud, water |
| `shelly-client` | REST client for Shelly devices | boiler, heating, shelly-cloud, water |

`cholewa-commons` and `cholewa-security` are intentionally hosted on the personal
`magikabdul` GitHub account (not the org): they are also used by services outside this
project. Their packages come from `maven.pkg.github.com/magikabdul/*` (pom server id
`github-prv`); the org libraries use `.../smart-home-automation-system/*`
(`github-org-smart-home`). Do not propose moving them into the org.

### Other repositories

- `amx` — AMX/NetLinx sources for the physical control system (not Java).
- `web-application` — Angular + Angular Material frontend (desktop-first, responsive).
  Claude has full autonomy here, but every change goes through a feature branch and a PR
  reviewed by the user. Key decisions (details in the repo's `CLAUDE.md`): household-member
  profiles without login (profile picker persisted in the browser, future JWT-ready),
  data via polling of `api-gateway-service` behind a per-domain data-access layer
  (SSE-ready), personalized home page per profile (own room + shortcuts + common areas).
- `deployment-tools` — **PRIVATE**: Kubernetes manifests, local `kind` cluster setup,
  pipelines, RabbitMQ config. Private infrastructure details belong here, never in
  public repos.
- `organization-repository` — local clone of the org's `.github` repo: organization
  profile README and this shared Claude configuration (`claude/`).
- `claude-tooling` — Claude Code plugin marketplace with the `smart-home` plugin
  (org skills — see `claude/skills.md`).
- `tenczynek-network-setup` — **PRIVATE**: home network setup; dormant (last change
  2022), not cloned in the workspace.

## Architecture notes

- Reactive stack everywhere: Spring WebFlux, no blocking calls in service code.
- Async messaging via RabbitMQ: `amx-service`, `heating-service`, `notification-service`.
- Service discovery: Kubernetes-native (k8s Services + DNS). Eureka
  (`service-discovery`) is being phased out — see Pending architecture changes.
- External traffic: k8s → `api-gateway-service` → internal services.

## Pending architecture changes (decided 2026-07, executed by the user)

- `service-discovery` (Eureka) — will be removed: k8s DNS covers discovery. This implies
  removing the `spring-cloud-starter-netflix-eureka-client` dependency and config from
  `api-gateway-service`, `boiler-service`, `shelly-cloud-service` and `water-service`,
  and replacing the discovery locator in `api-gateway-service` with explicit static
  routes using k8s DNS names.
- `cholewa-security` — stays; possible future use for auth in `api-gateway-service`.
- **Toolchain migration**: all existing services and libraries move from
  Java 17 / Spring Boot 4.0.1 to Java 21 / Spring Boot 4.1.0. Until a repo is migrated,
  its pom and README badges may still show the old versions.
  Progress: `cholewa-commons` migrated and released as **1.0.0** (2026-07-22, HAS-117) —
  a breaking release (Java 21 bytecode, Jackson 3); consumers stay on 0.2.x until their
  own migration. `cholewa-security` migrated and released as **1.0.0**
  (2026-07-22, HAS-118) — Java 21 bytecode (no code / no Jackson to migrate); no
  consumers yet, so no coordinated bumps needed. `smart-home-sdk` migrated and
  released as **1.0.0** (2026-07-23, HAS-119) — Java 21 + Jackson 3 (dropped
  `jackson-databind`, generated models keep `com.fasterxml.jackson.annotation` only),
  which closed the 4 Dependabot jackson-databind alerts. Its consumers
  (`amx-service`, `boiler-service`, `database-service`, `heating-service`,
  `shelly-cloud-service`, `water-service`) stay on the old SDK (0.1.x) until their own
  Java 21 migration — this release unblocks them.

## Conventions

- **Target toolchain: Java 21, Spring Boot 4.1.0** (`spring-boot-starter-parent`), Maven,
  groupId `cloud.cholewa`. New services and libraries start on the target versions.
  Existing repos are still on Java 17 / Spring Boot 4.0.1 and will be migrated soon
  (see Pending architecture changes); `cholewa-commons` and `cholewa-security` are
  already on the target versions, and `smart-home-sdk` is on Java 21 (all released as
  1.0.0; `smart-home-sdk` has no Spring Boot parent).
- Libraries are consumed from GitHub Packages: org libraries from
  `maven.pkg.github.com/smart-home-automation-system/*`, the personal-account libraries
  (`cholewa-commons`, `cholewa-security`) from `maven.pkg.github.com/magikabdul/*` —
  see the note under the library table.
- CI/CD — GitHub Actions in every repo:
  - `CI.yml` — build + tests on push/PR.
  - `sonar.yml` — SonarCloud analysis.
  - Services: `release.yml` — release builds a Docker image pushed to Docker Hub.
  - Libraries: `package.yml` — release publishes the artifact to GitHub Packages.
- A new microservice mirrors the structure and workflows of `water-service`
  (the reference service) — use the `new-service` skill from the `smart-home` plugin
  (`claude-tooling` repo); for libraries, `new-library` with `smart-home-sdk` as the
  reference.

## Working rules for Claude

- **Spring Boot services and libraries**: the user writes the code themselves. Do NOT write
  or modify code there unless explicitly asked. Default contributions: analysis, code
  review, security review, answering questions.
- **`web-application`**: full autonomy — Claude designs and implements the frontend.
- **`amx`**: NetLinx language; analysis and suggestions, ask before modifying.
- Never commit or push unless explicitly asked.
- **All changes to Spring services, libraries and `web-application` go through pull
  requests** — no direct commits to `main`. Branch naming: **`feature/HAS-<n>`**, where
  `<n>` is the Jira task number (HAS project). When no Jira task covers the change,
  create one first (`jira-backlog`) or confirm with the user how to proceed.
- All repos except `deployment-tools` are public: never put secrets, tokens, IP addresses,
  or private infrastructure details into files of public repos.
  - Accepted risk (conscious decision, 2026-07): private **LAN IPs** already present in
    service configs (e.g. `application.yaml`) are tolerated — keeping them beats the
    overhead of maintaining k8s secrets for LAN addresses. Do not flag them in reviews.
    Secrets, tokens and credentials remain strictly forbidden.
