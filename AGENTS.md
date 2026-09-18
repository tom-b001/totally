# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd prime` for full workflow context.

> **Architecture in one line:** Issues live in a local Dolt database
> (`.beads/dolt/`); cross-machine sync uses `bd dolt push/pull` (a
> git-compatible protocol), stored under `refs/dolt/data` on your git
> remote — separate from `refs/heads/*` where your code lives.
> `.beads/issues.jsonl` is a passive export, not the wire protocol.
>
> See [SYNC_CONCEPTS.md](https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md)
> for the one-screen overview and anti-patterns (don't treat JSONL as the
> source of truth; don't `bd import` during normal operation; don't
> reach for third-party Dolt hosting before trying the default).

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Building & Testing

The Xcode project is `Totally/Totally.xcodeproj`, scheme `Totally` (iOS 17+).

**Do NOT run a full build + test before picking up a new bead.** Selecting the
next bead is a read-only planning step (`bd ready` / `bd show`) — it does not
require compiling or testing the app. Only build and test as part of *verifying
the bead you are actually implementing*, at the point where the change is done.
Running the whole suite just to choose work wastes minutes per bead.

**Reuse the already-running simulator; do not boot a new one.** If a simulator
is already booted, target it by name or id instead of spinning up a fresh
device:

```bash
# See what's already booted (use this device):
xcrun simctl list devices booted

# Test against the currently-booted simulator (do NOT launch another):
xcodebuild test \
  -project Totally/Totally.xcodeproj \
  -scheme Totally \
  -destination "platform=iOS Simulator,id=<booted-device-udid>"
```

Use the UDID from `xcrun simctl list devices booted`. Only if nothing is booted
should you pick and boot a simulator. Never use a bare `-destination
'generic/platform=iOS Simulator'` or a fixed device name that forces a new
device to launch when one is already running.

## Xcode Project Conventions

**New Swift files are NOT auto-discovered — you must edit `project.pbxproj`
by hand.** This project uses classic (non-synchronized) PBXGroups, not
Xcode 16's filesystem-synchronized folders. Adding a `.swift` file requires
four manual edits to `Totally/Totally.xcodeproj/project.pbxproj`:
1. A `PBXBuildFile` entry
2. A `PBXFileReference` entry
3. Adding that file reference into the right `PBXGroup` (e.g. `Domain`,
   `Persistence`, `Scanner`)
4. Adding the build-file entry to the target's `Sources` build phase

Look at a prior file-adding commit (e.g. `git show 68036d1 --
Totally/Totally.xcodeproj/project.pbxproj`, which added `Persistence/`) for
the exact shape to copy. Forgetting any one of the four edits means the file
compiles-but-isn't-linked or doesn't show up in Xcode.

**`Info.plist` is intentionally minimal** (just launch screen + supported
orientations) — there are no usage-description keys yet. Any bead that adds
a new hardware/privacy-sensitive capability (camera, location, photo
library, etc.) must add its own `NSXxxUsageDescription` key; nothing else
will remind you.

**Camera/VisionKit code cannot be exercised in the Simulator.** For beads
touching `DataScannerViewController` or similar camera APIs, "verification"
means compile success plus unit tests on the pure/testable logic — not an
actual live scan. Don't hold up a PR waiting for simulator camera output
that will never appear.

**UI wiring convention:** new modal screens (sheets/full-screen covers)
follow the completion-closure pattern already used by `ManualEntryView`
(the presenter — e.g. `HomeView` — owns the `@State` and passes an `onAdd`
style closure into the modal) rather than a shared view model. Follow this
shape for new scanner/editor screens for consistency.

## Bead Selection: Confirming Milestone Completion

When applying the depth-first milestone heuristic, don't just eyeball
`bd ready` — confirm a milestone is actually done with:
```bash
bd show <epic-id>
```
This prints each child's status and an explicit `eligible for close` line
once all children are closed, which is a faster and more reliable signal
than inferring completion from what's missing in `bd ready --type=task`.

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:970c3bf2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->
