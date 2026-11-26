# Working rules for Claude — the owner's standing rules

Rules the owner gave in conversation, kept in git so that they survive a new system or another machine (owner,
2026-11-26). Imported into every session beside `organization.md`, which holds the map, the contracts and the rules that
came with the architecture; where the two overlap, the more specific wording here decides. A rule of one repository
moves into that repository's `CLAUDE.md` with its next task and is then removed from the section below.

## Conversation

- Talk to the owner in Polish only - every message, the task list and the next-step box, reports of skills; artifacts
  (code, README, commits, PR texts, Jira, docs) are English. The same rule is in his global `~/.claude/CLAUDE.md`.
- **A question of the owner is answered first** (owner, 2026-11-26): when a message asks something, give the answer
  before any change is made - also when the same message tells Claude to do something.
- Ask one question per message, after listing what is settled.
- A command for the owner to run goes into the closing message, as a ready PowerShell line.
- A fact that is not known - of a device, a setting, a status - is asked or read at the source, never guessed.

## Git, pull requests and reviews

- No AI attribution anywhere in git history or on GitHub - no `Co-Authored-By` trailer, no "generated with" line, in
  commits, PR titles, descriptions and comments.
- Commit and push only once the owner said to. **In this project the commit message is not shown for approval** (owner,
  2026-11-26 - an exception to his global rule, which asks for it): once it is agreed that a change is to be committed or
  pushed, write the message yourself and commit at once. Still never commit or push without that agreement.
- **`service-review` and `/code-review` run on the local change before it is pushed** (owner, 2026-11-26): the first
  push of a branch already carries their fixes, so the checks on GitHub do not run several times for one change. Order
  for a service or a library: implement, `mvn verify`, both reviews on the local diff and their fixes, the owner's look in
  IntelliJ (the change uncommitted), then commit, push and the PR - with the outcome of the reviews recorded on it. A
  change pushed later (a fix after the PR, after a deploy) is reviewed the same way before its push. The PR records only
  reviews that really ran.
- A PR is ready only with every check green and zero new Sonar issues - read the issue list
  (`api/issues/search?componentKeys=...&pullRequest=<n>&resolved=false`), a passed quality gate can hide them.
- The owner merges every PR. Never merge and never offer to; report it ready and wait.
- A prerequisite change in another repository is folded into the active task - no extra Jira task; a repository without
  a `CLAUDE.md` gets one in the same PR.
- A task that changes endpoints includes the `sync-bruno` proposal before its quality gate; nothing is written to the
  collection before the owner accepts it.
- The README is the last commit of a feature PR, re-checked before every push; the manifest of `deployment-tools` and the
  org docs are committed after the verified rollout.

## Release and deploy

- Release and deploy are the owner's commands, handed over one at a time and only when they can run right then (never
  "after X, run Y"): `gh release create --repo <owner>/<repo> ...` once the merge was confirmed at the source;
  `kubectl apply -f <workspace>/deployment-tools/workshop/<service>.yaml` once the image is on Docker Hub. A library is
  released and available before its consumer is pushed.
- Verifying the rollout (the pod, its image digest against Docker Hub, a clean start) and closing the docs afterwards are
  Claude's, unasked.
- A newly mandatory variable is no blocker for the owner's local runs (he keeps an IntelliJ env file) - name it.
- A step that needs Docker is never skipped when Docker is down - ask the owner.

## Jira

- Work only on tasks of the active sprint; for one outside it, ask to move it in first.
- Starting a task that is in "To Do", move it to "In Progress" - the only status Claude changes.
- No sentence about a Jira status, a PR or the cluster without a read of it in the same turn; a status not read in this
  turn is not mentioned, and the owner is never told to move a task.
- "The service starts locally" of a Definition of Done is met by a clean start of the pod (owner, 2026-10-26).
- A task the owner abandons is Done with the label `abandoned`; it is not counted as delivered and not proposed again.

## The workspace and this machine

- Other Claude sessions work in this workspace: never loop git over all repositories, never `checkout` a repository that
  is on a branch you did not create.
- Closing a task, only in the repositories it touched: `main`, pull, `fetch --prune`, delete the merged branch, stop the
  dev servers you started.
- Shell (Windows, Git Bash): never write a file through a heredoc - the Write tool, then run it; never a Spring `${...}`
  inside a double-quoted bash string; no `python` and no `jq` - use `node`; pods are selected by `-l name=<service>`. The
  rest is in `SETUP.md`, "Shell pitfalls".
- Claude never types a password into a device or a page - the owner logs in. Credentials are read only by the scripts of
  `SETUP.md` 4a, never from `.env` directly.
- Web research: the built-in search and fetch first; Firecrawl (paid) only when they fail.
- A standing rule the owner gives is written into git - this file, or the `CLAUDE.md` of the repository it concerns - not
  only into Claude's local memory.

## Java written by Claude

- Controller -> service -> repository: a controller never injects a repository.
- A branch on the value of a `Mono` is a chain (`filter`, `switchIfEmpty`), not an `if` or a ternary; pure helpers
  without a publisher may keep their `if`.
- Classes are imported, never fully qualified inline - in tests too.

## Device registry

- A new device is named in English, without its room (the older Eaton names stay).
- Devices are written to the production registry one by one, each after the owner accepts it; what is registered or goes
  wrong is noted in the `devices.md` of `deployment-tools` in the same step.

## Rules of one repository

### web-application

- **The look is agreed with the owner first, without the test suites** (owner, 2026-11-26; the suites take about half an
  hour, and a small correction would cost that again): after a change show it in the live preview and give the URL of
  each changed view; iterate there until the owner confirms the look. Only then run the build and the suites locally,
  once, and - when they pass - update the docs, push and open the PR. From the first version of a new view on.
- The message that calls a PR ready carries the preview URLs, the PR and the CI run.
- When a task crosses the initial-bundle warning, raise the threshold in that PR and say so in one line; never shorten
  texts for it.

### blinds-service

- Every program of the blinds runs in this service (owner, 2026-10-18): the schedules on the Shelly devices, the scenes
  of the Shelly cloud and the NetLinx flag `ROLLER_SCHEDULES_ENABLED` are switched off, not removed - never re-enable one
  without the owner.
- HAS-249 (the wind and frost protection) was abandoned on 2026-11-13 - do not propose it.

### heating-service

- The loft (never heated) and bathroom down (no window) have no opening sensor by design - `no sensor` there is no gap.
- The schedules (owner, 2026-10-31): a low base in every gap instead of no schedule; the bathroom radiators are towel
  rails, 30 °C meaning "on for the window"; the 24 °C of the floors is a timer with a safety. Ask before changing a
  temperature the owner chose.

### energy-service

- Never propose a test that cuts the grid, unplugs the SOLAX dongle or the SOFAR logger, or touches an inverter (the
  warranty; owner, 2026-11-01) - such a Definition-of-Done item is proven by the next real event.
- Load shedding (epic HAS-520, not built; owner, 2026-11-25): the grid is judged by the SOLAX alone; it starts at once
  with an outage and ends after 10 unbroken minutes of grid, the frequency not judged; idle plugs are cut at once, working
  ones after a message once their draw falls, the kettle always; the states come back by themselves; the switch is on by
  default; never touched: fridges, the infrastructure, the AMX, computers, lights, blinds, gates, the boiler room.

### aircon-service

- The frost protection of sanctum is proven by a real cold night only - no staged test by raising the schedule; its start
  stays strictly below 8.0 °C (owner, 2026-11-16 / 24).

### water-service

- Never ask for a manual regeneration of the softener as a test (salt and water; owner, 2026-11-09).

### appliance-service

- No door or angle sensors on the appliances, definitively (the dishwasher opens itself) - do not propose them.

### gate-service

- Number plates are information only - never propose opening the gate by a plate (the test of 2026-11-21: readable by
  day, never at night).
- No cable can be laid at the driveway gate - never propose wiring (owner, 2026-11-16).

### amx

- Before any TPDesign4 work ask the owner to open it on a screen nothing covers, and work on a copy of the panel file.

### media-service (epic HAS-508, not built)

- The state of the amplifier cannot be read - never design a status or a detection; its unlock is a button only, never
  automatic after the grid returns (owner, 2026-11-24).
