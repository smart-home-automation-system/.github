# Claude Code configuration — how it works and how to set it up on a new machine

This document describes the whole Claude Code setup for the `smart-home-automation-system`
organization and the exact steps to reproduce it on another machine.

## How the configuration is layered

The project is a **multi-repo workspace**: one directory (e.g.
`~/programming/smart-home-automation-system`) containing every repository of the
organization cloned side by side. The workspace directory itself is NOT a git repository.

| Layer | Location | Versioned in | Loaded when |
|---|---|---|---|
| 1. Organization context | `<workspace>/CLAUDE.md` → imports `organization-repository/claude/organization.md` and `claude/skills.md` | `.github` repo | Every Claude session started anywhere inside the workspace |
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
- Java 17 (Temurin) + Maven
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

To recreate this workspace and configuration on another machine, see
`organization-repository/claude/SETUP.md`.
```

### 4. Maven access to GitHub Packages

Services consume the `cloud.cholewa` libraries from GitHub Packages, which requires
authentication even for public packages. In `~/.m2/settings.xml` add servers matching the
ids used in the poms (`github-org-smart-home`, `github-prv`, and `github` for publishing),
with a PAT that has `read:packages` (plus `write:packages` if publishing locally):

```xml
<settings>
  <servers>
    <server><id>github-org-smart-home</id><username>USERNAME</username><password>PAT</password></server>
    <server><id>github-prv</id><username>USERNAME</username><password>PAT</password></server>
    <server><id>github</id><username>USERNAME</username><password>PAT</password></server>
  </servers>
</settings>
```

### 5. Skills

- Built-in Claude Code skills (`/code-review`, `/security-review`, `/review`, …) work out
  of the box — see `claude/skills.md` for which to use where.
- Org skills live in the `claude-tooling` marketplace repo (plugin `smart-home`,
  7 skills — see `claude/skills.md`). Install once per machine:

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
