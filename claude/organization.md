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
| `shelly-cloud-service` | 6008 | Shelly cloud integration — **unfinished, local-only** (not a git repo, no GitHub repo yet; kept as is for now) |

Do not confuse `api-gateway-service` (HTTP edge / Spring Cloud Gateway) with
`amx-service` (AMX hardware bridge).

### Shared libraries (Maven, `cloud.cholewa` group)

| Library | Purpose | Current consumers |
|---|---|---|
| `cholewa-commons` | Common utilities | ai, amx, api-gateway, boiler, database, heating, notification, shelly-cloud, water |
| `cholewa-security` | Security/auth | none yet — kept for possible future auth in `api-gateway-service` |
| `smart-home-sdk` | Shared domain / API models | amx, boiler, database, heating, shelly-cloud, water |
| `shelly-client` | REST client for Shelly devices | boiler, heating, shelly-cloud, water |

`cholewa-commons` and `cholewa-security` are intentionally hosted on the personal
`magikabdul` GitHub account (not the org): they are also used by services outside this
project. Their packages come from `maven.pkg.github.com/magikabdul/*` (pom server id
`github-prv`); the org libraries use `.../smart-home-automation-system/*`
(`github-org-smart-home`). Do not propose moving them into the org.

### Other repositories

- `amx` — AMX/NetLinx sources for the physical control system (not Java). Like
  `cholewa-commons` and `cholewa-security`, this one lives on the personal `magikabdul`
  account (`magikabdul/amx-tenczynek`), not in the org — the workspace directory is named
  `amx`.
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
  `api-gateway-service`, `boiler-service` and `shelly-cloud-service`,
  and replacing the discovery locator in `api-gateway-service` with explicit static
  routes using k8s DNS names. `water-service` is **done** (HAS-127): its Java 21 migration
  dropped the Eureka client together with the whole Spring Cloud BOM, because the 2025.1.x
  release train is built against Boot 4.0.7 and no Boot 4.1 train exists yet — the service
  used no `DiscoveryClient`, `@LoadBalanced` or `lb://` URIs, so the removal was
  configuration-only. Expect the same forced choice in every remaining Spring Cloud
  consumer.
- `cholewa-security` — stays; possible future use for auth in `api-gateway-service`.
- **Toolchain migration**: all existing services and libraries move from
  Java 17 / Spring Boot 4.0.1 to Java 21 / Spring Boot 4.1.0. Until a repo is migrated,
  its pom and README badges may still show the old versions.
  Progress: `cholewa-commons` migrated and released as **1.0.0** (2026-07-22, HAS-117) —
  a breaking release (Java 21 bytecode, Jackson 3); consumers stay on 0.2.x until their
  own migration. It has since had three feature releases — **1.0.1** (2026-07-23, HAS-131 —
  select `ExceptionProcessor` by exception hierarchy, not exact class), **1.1.0**
  (2026-07-24, HAS-132 — log handled errors in every `ExceptionProcessor`) and **1.2.0**
  (2026-07-26, HAS-137 — render database integrity violations as 400 instead of 500);
  current latest is **1.2.0**, adopted by `database-service` and `water-service`
  (`notification-service` and `ai-service` are on 1.1.0). `cholewa-security` migrated and released as **1.0.0**
  (2026-07-22, HAS-118) — Java 21 bytecode (no code / no Jackson to migrate); no
  consumers yet, so no coordinated bumps needed. `smart-home-sdk` migrated and
  released as **1.0.0** (2026-07-23, HAS-119) — Java 21 + Jackson 3 (dropped
  `jackson-databind`, generated models keep `com.fasterxml.jackson.annotation` only),
  which closed the 4 Dependabot jackson-databind alerts. `database-service` adopted it
  during its own migration (HAS-126); the remaining consumers (`amx-service`,
  `boiler-service`, `heating-service`, `shelly-cloud-service`) stay on
  the old SDK (0.1.x) until their own Java 21 migration — this release unblocks them.
  It has since had one feature release — **1.1.0** (2026-07-28, HAS-136 — `required` on
  the Eaton configuration models, so the generated models carry `@NotNull` and a consumer
  can validate the payload with `@Valid` alone); current latest is **1.1.0**, adopted by
  `database-service` and `water-service`.
  `shelly-client` migrated and released as **1.0.0**
  (2026-07-23, HAS-120) — Java 21 + Jackson 3 (dropped `jackson-databind`;
  a model-only library, generated models keep `com.fasterxml.jackson.annotation` only),
  which closes its 4 Dependabot jackson-databind alerts. `water-service` is its first
  consumer on 1.0.0 (adopted during HAS-127); the remaining ones (`boiler-service`,
  `heating-service`, `shelly-cloud-service`) stay on the old client (0.0.x) until their
  own Java 21 migration.
  The first **service** migrated is `notification-service` — Java 21 / Spring Boot 4.1.0,
  released **0.1.0** (2026-07-24, HAS-124). It does not use `smart-home-sdk` or
  `shelly-client`; during the migration it adopted `cholewa-commons` 1.1.0 (a new consumer
  of that library). The second service migrated is `ai-service` — Java 21 / Spring Boot 4.1.0,
  released **0.1.0** (2026-07-24, HAS-125), from an outlier Spring Boot 3.3.4. It uses
  neither `smart-home-sdk` nor `shelly-client` and adopts `cholewa-commons` 1.1.0 as a new
  consumer, wiring its `GlobalErrorExceptionHandler` for consistent error responses like
  `notification-service`. Its AI framework changed from
  **langchain4j to Spring AI 2.0.0** — langchain4j's Spring Boot starter (1.x) is not Boot 4
  compatible, whereas Spring AI 2.0.0 targets Boot 4.1 / Spring Framework 7 — so the service
  now calls OpenAI through a reactive Spring AI `ChatClient`. The third service migrated is
  `database-service` — Java 21 / Spring Boot 4.1.0, released **0.2.0** (2026-07-25, HAS-126),
  deployed and verified on the cluster; it has since moved through the Eaton configuration
  hardening epic (HAS-134) to **0.4.0** (2026-07-28) — unique `(point, gateway)` (HAS-138),
  400 for an unknown gateway (HAS-135) and request body validation (HAS-136). It is the
  **first migrated service that consumes the
  shared domain models**, so it is also the first consumer of `smart-home-sdk` (1.0.0 at the
  time of the migration, now 1.1.0; `cholewa-commons` 1.1.0 → now 1.2.0); the REST contract
  it serves to `amx-service` is unchanged, so
  `amx-service` keeps working on the old library versions. Two things surfaced there that
  every following service migration will hit: logbook 4.x needs the optional
  `spring-boot-http-client` module on Boot 4.1 or the context will not start, and the k8s
  manifest must launch the image with `-jar application.jar` — Boot 4 dropped `layertools`,
  so the old `JarLauncher` command crashes the pod (the `Dockerfile` needs
  `-Djarmode=tools ... extract --layers` for the same reason).
  The fourth service migrated is `water-service` — Java 21 / Spring Boot 4.1.0, released
  **0.2.0** (2026-07-29, HAS-127), deployed and verified on the cluster. It is the first
  migrated service using **both** shared model libraries (`smart-home-sdk` 1.1.0 and
  `shelly-client` 1.0.0, plus `cholewa-commons` 1.2.0) and the first to drop Eureka. Three
  things it added to the migration playbook: Boot 4.1 moved the `WebClient`
  auto-configuration out of `spring-boot-starter-webflux`, so a service building its own
  `WebClient` needs `spring-boot-starter-webclient` (otherwise there is no autoconfigured
  `WebClient.Builder` at all); the surefire `includes` added during a migration only match
  `**/*Test.java`, so a class named `...Tests` silently stops running; and the k8s manifest
  has to carry the `env` block with the database properties — `water-service` had none, and
  before the migration a broken `spring.flyway.url` default masked it. The remaining
  services (`amx-service`, `boiler-service`, `heating-service`, `shelly-cloud-service`)
  stay on Java 17 / Spring Boot 4.0.x until their own migration; `api-gateway-service` and
  `service-discovery` are a separate case — both still run **Spring Boot 3.5.0 on Java 21**
  (Spring Cloud), and `service-discovery` is being retired anyway.

## Conventions

- **Target toolchain: Java 21, Spring Boot 4.1.0** (`spring-boot-starter-parent`), Maven,
  groupId `cloud.cholewa`. New services and libraries start on the target versions.
  All four libraries are already migrated (`cholewa-commons` and `cholewa-security` on the
  target versions, `smart-home-sdk` and `shelly-client` on Java 21 without a Spring Boot
  parent; all first released as 1.0.0 — current latest: `cholewa-commons` **1.2.0**,
  `smart-home-sdk` **1.1.0**, `cholewa-security` and `shelly-client` still **1.0.0**),
  and four services — `notification-service`, `ai-service`,
  `database-service` and `water-service` — are on the target toolchain. The rest
  (`amx-service`, `boiler-service`, `heating-service`, `shelly-cloud-service`) are still on
  Java 17 / Spring Boot 4.0.x, and `api-gateway-service` / `service-discovery` on Spring Boot
  3.5.0 / Java 21; all will be migrated (see Pending architecture changes).
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
  (the reference service — since HAS-127 it is itself on the target toolchain, so its pom,
  `Dockerfile` and workflows can be copied as they are) — use the `new-service` skill from
  the `smart-home` plugin (`claude-tooling` repo); for libraries, `new-library` with
  `smart-home-sdk` as the reference.

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
  - **Exceptions — commit straight to `main`, no branch or PR:** `organization-repository`
    (this `.github` repo), `deployment-tools` and `claude-tooling`. Do not create
    `feature/*` branches or PRs for these; just commit to `main` and push (still only when
    explicitly asked). They also do not need a Jira task of their own — a change there is
    usually a side effect of work tracked elsewhere, so reference that task in the commit
    message when one exists.
- All repos except `deployment-tools` are public: never put secrets, tokens, IP addresses,
  or private infrastructure details into files of public repos.
  - Accepted risk (conscious decision, 2026-07): private **LAN IPs** already present in
    service configs (e.g. `application.yaml`) are tolerated — keeping them beats the
    overhead of maintaining k8s secrets for LAN addresses. Do not flag them in reviews.
    Secrets, tokens and credentials remain strictly forbidden.
