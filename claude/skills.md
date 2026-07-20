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

## Planned custom skills (org plugin marketplace, not yet created)

| Skill | Scope | Purpose |
|---|---|---|
| `new-service` | workspace | Scaffold a new microservice from the `water-service` reference: pom, Dockerfile, `CI.yml`/`release.yml`/`sonar.yml`, README, CLAUDE.md; register it in `organization.md` and the org profile README |
| `new-library` | workspace | Same for a library (`package.yml` → GitHub Packages) |
| `service-review` | services/libraries | Review against org conventions (reactive rules, commons/security usage, Rabbit contracts, dependency versions) |
| `release` | services/libraries | Guide a release: version bump, tag, correct workflow, artifact destination |

Repo-local skills (committed in the repo they concern, not shared):

- `web-application/.claude/skills/` — frontend-specific skills (e.g. verify-in-browser),
  to be defined when the frontend is bootstrapped.
- `deployment-tools/.claude/skills/` — deploy/rollout helpers (private repo).
