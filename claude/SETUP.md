# Claude Code configuration — how it works and how to set it up on a new machine

This document describes the whole Claude Code setup for the `smart-home-automation-system`
organization and the exact steps to reproduce it on another machine.

## How the configuration is layered

The project is a **multi-repo workspace**: one directory (e.g.
`~/programming/smart-home-automation-system`) containing every repository of the
organization cloned side by side. The workspace directory itself is NOT a git repository.

| Layer | Location | Versioned in | Loaded when |
|---|---|---|---|
| 1. Organization context | `<workspace>/CLAUDE.md` → imports `organization-repository/claude/organization.md`, `claude/skills.md` and `claude/working-rules.md` (the owner's standing rules) | `.github` repo | Every Claude session started anywhere inside the workspace |
| 1a. Detail of one service | `organization-repository/claude/services/<name>.md` - what a service, a library or the dashboard does, its release history and what it depends on; **not imported**, read on demand as `organization.md` asks | `.github` repo | When a task works on that repository or on one that talks to it |
| 2. Repo context | `<repo>/CLAUDE.md` (+ optional `<repo>/.claude/settings.json`, `<repo>/.claude/skills/`) | each repo | Sessions started inside that repo |
| 3. Shared skills | org plugin marketplace (planned, repo `claude-tooling`) + built-in skills | its own repo | Everywhere, once installed |

Verified behaviors this setup relies on:

- Claude Code walks **up** the directory tree from the working directory and loads every
  `CLAUDE.md` it finds — including ones **above the git repo root**. That is why a single
  `CLAUDE.md` in the workspace directory provides organization context to all repos.
- `@path` imports inside `CLAUDE.md` are resolved relative to that file, so the workspace
  file can import content versioned inside `organization-repository`.
- `.claude/skills/` and `.claude/settings.json` do **NOT** inherit from parent directories
  above the repo root. Skills shared across repos must come from `~/.claude/skills/`
  (personal) or from an installed plugin. Settings must be per-repo or in
  `~/.claude/settings.json`.
- The layer-1 file only exists in the workspace. A repo cloned standalone (or used in CI)
  gets only its own `CLAUDE.md`, so each repo's `CLAUDE.md` must minimally stand on its
  own (what the repo is, how to build it).

## Setting up a new machine

### 1. Prerequisites

- `git` + [GitHub CLI](https://cli.github.com/) (`gh auth login`, SSH keys configured)
- Java 21 + recent Maven (3.9+); Java 17 additionally, while pre-migration repos remain
- Docker (for images and local `kind` cluster; `kind` + `kubectl` if deploying)
- Node.js LTS + npm (for `web-application`)
- [Claude Code](https://code.claude.com) (`npm install -g @anthropic-ai/claude-code` or native installer)

### 2. Clone the workspace

```bash
mkdir -p ~/programming/smart-home-automation-system
cd ~/programming/smart-home-automation-system

# All repos of the org, side by side:
gh repo list smart-home-automation-system --limit 100 --json name -q '.[].name' \
  | xargs -I{} git clone "git@github.com:smart-home-automation-system/{}.git"

# The org's `.github` repo must be cloned under the name `organization-repository`
# (the workspace CLAUDE.md imports from that path):
mv .github organization-repository 2>/dev/null \
  || git clone git@github.com:smart-home-automation-system/.github.git organization-repository
```

Note: `deployment-tools` is private — requires being authenticated as the org owner.

### 3. Create the workspace `CLAUDE.md`

This file is not versioned (the workspace is not a repo). Create
`~/programming/smart-home-automation-system/CLAUDE.md` with exactly:

```markdown
# Smart Home Automation System — workspace

This directory is a multi-repo workspace: every subdirectory is a separate clone of a
repository from the GitHub organization `smart-home-automation-system`. This file is NOT
under version control — the shared content lives in the `organization-repository` repo
(the org's `.github` repo) and is imported below.

@organization-repository/claude/organization.md

@organization-repository/claude/skills.md

@organization-repository/claude/working-rules.md

To recreate this workspace and configuration on another machine, see
`organization-repository/claude/SETUP.md`.
```

### 3a. Create the global `~/.claude/CLAUDE.md`

The owner's rules for every project on the machine live in `~/.claude/CLAUDE.md` (`C:\Users\<user>\.claude\CLAUDE.md`),
which is in no repository. Recreate it with these sections - the rules themselves are repeated for this project in
`claude/working-rules.md`, so a session here follows them even without the global file:

- **Browser automation (claude-in-chrome)** - a standing permission to use the plugin in every project: look at a
  logged-in web UI yourself instead of asking for a refresh; the Chrome session is already signed in, never look for
  credentials in files; open a new tab and close it when done; reading is free, anything that writes to a production
  system stays subject to the rules of that project.
- **Git commits and pull requests** - never add AI attribution anywhere in git history or on GitHub; before every
  commit show the proposed message and wait for approval, commit and push only after it.
- **Language** - the whole conversation in Polish, the next-step box and the task list included; only artifacts (code,
  README, commits, PR texts, Jira) are English.

### 3b. Shell pitfalls (Windows, Git Bash)

What cost time on the owner's machine - the short form is in `claude/working-rules.md`:

- Never write a file through a heredoc (`<<EOF`) - use the Write tool, then run the file with Bash.
- A Spring placeholder `${...}` inside a double-quoted bash string is expanded by the shell - single quotes.
- No `python` and no `jq` on the machine: parse with `node` (or PowerShell `ConvertFrom-Json`).
- The working copies have CRLF line endings (`core.autocrlf`): normalise before a multi-line replace done by a script;
  a file written by PowerShell carries `\r` - `tr -d '\r'` before bash reads it line by line.
- `MSYS_NO_PATHCONV=1` before a command whose argument starts with `/` and is not a path (`kubectl exec ... -p /vhost`,
  `docker run -c ssl=on` with paths).
- Pods carry the label `name=<service>` (not `app=`).
- Stop a port-forward by its own PID, never by killing every `kubectl.exe` - other sessions run theirs.
- In `web-application` run prettier on the changed files only, never on a glob.
- `sleep N; command` chains are blocked in the Claude desktop app - wait with an `until` loop or `gh run watch`.

### 4. Maven access to GitHub Packages

Services consume the `cloud.cholewa` libraries from GitHub Packages, which requires
authentication even for public packages. Maven does not create `~/.m2/settings.xml` on its
own (a fresh install only has `~/.m2/repository/`), and the stock
`<maven-home>/conf/settings.xml` is a commented-out template — so the file has to be
written by hand. Without it every build fails on a 401 while resolving `cloud.cholewa`
artifacts.

Generate a **classic** PAT at <https://github.com/settings/tokens> with `read:packages`
(add `write:packages` only if you want to `mvn deploy` a library from the machine). Two
things that regularly go wrong here:

- **Fine-grained tokens do not work** with the GitHub Packages Maven registry — it must be
  a classic PAT. A 401 with a correct-looking token is almost always this.
- The token used by the `gh` CLI is **not** reusable: its scopes (`repo`, `read:org`, …)
  do not include `read:packages`.

Then create `~/.m2/settings.xml` with servers matching the ids used in the poms
(`github-org-smart-home` for org libraries, `github-prv` for the personal-account ones,
and `github` — the `distributionManagement` id in every library pom — for publishing):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <!-- org libraries: smart-home-sdk, shelly-client -->
    <server>
      <id>github-org-smart-home</id>
      <username>USERNAME</username>
      <password>CLASSIC_PAT</password>
    </server>
    <!-- personal account libraries: cholewa-commons, cholewa-security -->
    <server>
      <id>github-prv</id>
      <username>USERNAME</username>
      <password>CLASSIC_PAT</password>
    </server>
    <!-- distributionManagement id in the library poms — only for local `mvn deploy` -->
    <server>
      <id>github</id>
      <username>USERNAME</username>
      <password>CLASSIC_PAT</password>
    </server>
  </servers>
</settings>
```

The same three ids cover every repository in the workspace, so this one file is all that is
needed. The repository URLs themselves are already declared in each pom
(`https://maven.pkg.github.com/magikabdul/*` and
`https://maven.pkg.github.com/smart-home-automation-system/*`) — nothing to add there.

`settings.xml` lives outside every git repo, so the token can stay in plain text; if you
prefer it encrypted, use `mvn --encrypt-password` with a `~/.m2/settings-security.xml`.
Maven re-reads the file on every run — no terminal or IDE restart needed.

Verify against any service that uses both libraries:

```
mvn -f <workspace>/amx-service/pom.xml -U dependency:resolve
```

It must download `cholewa-commons` and `smart-home-sdk` without a 401.

### 4a. Shared secrets for skills (`<workspace>/.env`)

Some skills (`jira-backlog`, `jira-sprint`, `quality-gate`) need credentials. They live in
a `.env` file in the workspace root — deliberately outside every git repository:

```
JIRA_EMAIL=<atlassian account email>
JIRA_API_TOKEN=<token from id.atlassian.com -> Security -> API tokens>
```

Claude never reads or sources that file itself (the auto-mode classifier refuses it, and
rightly so): it calls a script that loads the file and passes the credentials to `curl`
without printing them — `claude/scripts/jira-api.sh` of this repository. It lives here and
not in the plugin on purpose: an installed plugin runs from a cache directory named after
its version, so an allow rule pointing into it would break with every update; this clone
sits at the same place in every workspace.

Allow exactly that script in `<workspace>/.claude/settings.local.json` (or through
`/permissions` → Allow → Project settings (local)):

```json
{ "permissions": { "allow": ["Bash(bash organization-repository/claude/scripts/jira-api.sh:*)"] } }
```

The skills call it from the workspace root:
`bash organization-repository/claude/scripts/jira-api.sh <path below /rest/> [curl args]`.
The same pattern serves the RabbitMQ management API (`RABBITMQ_USERNAME` /
`RABBITMQ_PASSWORD`, its own allow rule); its script and host are private details and live
in `deployment-tools` (`scripts/rabbitmq-api.sh`).

The SolaX Developer Platform (the hybrid inverter and its battery, the energy work of
2026-10) uses the same pattern: `SOLAX_CLIENT_ID` / `SOLAX_CLIENT_SECRET` of the
application created at developer.solaxcloud.com, read by `claude/scripts/solax-api.sh`,
which fetches the OAuth2 token itself and never prints it:
`bash organization-repository/claude/scripts/solax-api.sh <path below /openapi/> [curl args]`,
with its own allow rule (`Bash(bash organization-repository/claude/scripts/solax-api.sh:*)`).

The Solarman Open API (the SOFAR inverter, HAS-330) too: `SOLARMAN_APP_ID` / `SOLARMAN_APP_SECRET`
granted by Solarman support, with `SOLARMAN_EMAIL` and `SOLARMAN_PASSWORD_SHA256` (the lowercase
SHA-256 of the account password) of the Solarman Smart account, read by
`claude/scripts/solarman-api.sh`, which takes the token itself and never prints it:
`bash organization-repository/claude/scripts/solarman-api.sh <path below the host> [curl args]`.

Docker Hub (the `cleanup-dockerhub` skill) too: `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` (a
personal access token with Read, Write, Delete), read by `claude/scripts/dockerhub-api.sh`,
which logs in itself and never prints the token or the JWT:
`bash organization-repository/claude/scripts/dockerhub-api.sh <path below /v2/> [curl args]`,
or `dockerhub-api.sh - [curl args] < paths.txt` for many calls under one login (`<user>` in a
path is replaced by the account name; there is no `jq` on the machine, so the skill parses the
answers itself). Its allow rule: `Bash(bash organization-repository/claude/scripts/dockerhub-api.sh:*)`.

### 5. Skills

- Built-in Claude Code skills (`/code-review`, `/security-review`, `/review`, …) work out
  of the box — see `claude/skills.md` for which to use where.
- Org skills live in the `claude-tooling` marketplace repo (plugin `smart-home`,
  the skills listed in `claude/skills.md`). Install once per machine:

  ```
  claude plugin marketplace add smart-home-automation-system/claude-tooling
  claude plugin install smart-home@smart-home-tooling
  ```

  (or the `/plugin` equivalents inside a session). The install is user-scoped, so the
  skills are available in every repo. When developing the skills themselves, add the
  marketplace from the local path instead:
  `claude plugin marketplace add <workspace>/claude-tooling`.

### 6. Daily usage

- Default: start `claude` inside the repo you work on — you get layer 1 + that repo's
  context automatically.
- Cross-repo work (e.g. a library change plus its consumer): start in the main repo and
  `/add-dir ../smart-home-sdk`. Skills from the added dir load automatically; its
  `CLAUDE.md` does not (set `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` to change that).
- Whole-project work (docs, workflow sweeps): start `claude` in the workspace root — all
  repos are in scope.
