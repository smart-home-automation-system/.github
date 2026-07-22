# Claude Code skills — what to use where

Which skills apply to which repository type. Built-in skills are available in every session;
custom org skills will be distributed later via a plugin marketplace (see SETUP.md).

## Built-in skills

| Skill | Spring services | Libraries | web-application | amx | deployment-tools |
|---|---|---|---|---|---|
| `/code-review` | ✔ primary tool — review user-written changes | ✔ must also check impact on consumers (see table in organization.md) | ✔ review Claude's own work before finishing | ✔ | ✔ manifest changes |
| `/security-review` | ✔ before every release | ✔ before every release | ✔ | — | ✔ (secrets, RBAC, exposed ports) |
| `/review <PR#>` | ✔ GitHub PR review | ✔ | ✔ | ✔ | ✔ |
| `verify` / `run` | only when asked (user builds and runs services themselves) | — | ✔ always after changes (`ng build` + tests) | — | — |
| `/init` | only for a brand-new repo without `CLAUDE.md` | same | same | — | — |

Notes:

- In Spring services and libraries Claude reviews but does not write code
  (see Working rules in `organization.md`).
- Library review checklist: breaking API changes require checking every consumer listed in
  `organization.md` and flagging required version bumps.

## Org skills (plugin `smart-home`, marketplace repo `claude-tooling`)

Install once per machine: `/plugin marketplace add smart-home-automation-system/claude-tooling`
then `/plugin install smart-home@smart-home-tooling` (user scope → available in every repo).

| Skill | Where to run | Purpose |
|---|---|---|
| `new-service` | workspace root | Scaffold a new microservice from the `water-service` reference (pom, Dockerfile, workflows, README, CLAUDE.md, GitHub repo, org docs) |
| `new-library` | workspace root | Same for a library (`package.yml` → GitHub Packages) |
| `service-review` | service/library repo | Review against org conventions: reactive discipline, reuse of shared libs, cross-repo contracts, version drift, public-repo hygiene |
| `release` | service/library repo | Guided release checklist (does not execute): pre-checks, semver proposal, `gh release create` command, artifact verification |
| `cleanup-releases` | anywhere | Prune old versions of a shared library (org libraries + `cholewa-commons`/`cholewa-security` on `magikabdul`): keep only the 3 newest, delete older GitHub releases **and** GitHub Packages versions (git tags stay); library name as argument, otherwise asks with the library list; consumer poms checked first, every deletion behind user confirmation |
| `cleanup-dockerhub` | workspace root | Prune all repos of the `magikabdul` Docker Hub account: per repo keep the 2 newest version tags + `latest`; tags referenced by `deployment-tools` manifests excluded and flagged; full plan displayed for user acceptance before any deletion; credentials `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` in `<workspace>/.env` |
| `sync-org-docs` | workspace root | Sync `organization.md` + profile README with the actual repo inventory (badges, tables, consumers, ports) |
| `deps-update` | workspace root | Version-drift matrix across all repos + ordered upgrade plan (libraries → services → frontend/CI) |
| `update-readme` | any repo | Bring a README to org standard: badges, description, API table from code (services) or install/usage (libraries) |
| `jira-backlog` | workspace root | Feature description → well-scoped Jira tasks (≤1 day each, `frontend`-labeled ones exempt) with implementation details, DoD checklists and epic assignment; created in the HAS backlog only after user acceptance. Credentials: `<workspace>/.env` |
| `jira-sprint` | anywhere | Monthly sprint on the HAS board: status report, rotation when ≥7 tasks Done (close + new 1-month sprint named `YYYY-MM <element>`, carry-over of unfinished tasks), top-up to ≥10 tasks agreed with the user; every mutation behind user confirmation |
| `quality-gate` | task's repo / workspace | DoD gate for a HAS task: applicability judgment per item (e.g. `sync-org-docs` only when the repo inventory changed), evidence-based verification (merged `feature/HAS-<n>` PR, CI on main, release artifacts, docs claims), PASSED/FAILED report; ticks verified checkboxes + leaves a report comment in Jira after user confirmation |

Repo-local skills (committed in the repo they concern, not shared):

- `web-application/.claude/skills/` — frontend-specific skills (e.g. verify-in-browser),
  to be defined when the frontend is bootstrapped.
- `deployment-tools/.claude/skills/` — deploy/rollout helpers (private repo).
