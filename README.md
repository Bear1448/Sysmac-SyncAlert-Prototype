# Sysmac SyncAlert (prototype)

Git workflow tooling for teams that work on **Omron Sysmac Studio** PLC projects.

## The problem

Sysmac Studio saves a whole machine program (ladder logic, variables, hardware config) as a single binary project file (`.smc2`). Git can store it, but it can't diff or merge it. If two engineers open the same project, make changes, and both push, one person's work gets silently overwritten. There's no way to merge them afterward.

Most controls teams handle this with "shout across the room before you open the project." That breaks down as soon as people are remote or on different shifts.

## The approach (Phase 1)

Phase 1 doesn't try to merge anything. It makes sure only one person edits at a time, and that everyone can see who is working on what.

1. **Lock before editing.** `lock-start.ps1` pulls the latest state, checks for an existing lock, writes `locks/<Project>.lock` (who, which PC, which branch, when, why), commits and pushes it, and posts `[LOCK]` to a Teams channel.
2. **Edit and export once.** The engineer works in Sysmac Studio and commits one export of the project.
3. **Release the lock.** `lock-end.ps1` removes the lock, pushes, and posts `[UNLOCK]` with a summary of what changed.
4. **Review.** A PR template walks the reviewer through the checklist (one export per PR, project still opens, no attempted merges).
5. **Restore points.** A weekly tag (e.g. `v2025.10.28-week4`) marks a known-good state to roll back to.

Because the lock is a file in the repo, Git itself settles races. If two people try to lock at the same moment, the second push is rejected, the script rolls back its local lock commit, and no false `[LOCK]` message goes out.

## Repo layout

```
tools/lock-start.ps1        claim the lock and notify Teams
tools/lock-end.ps1          release the lock and notify Teams
locks/                      one <Project>.lock file while someone is editing
.gitattributes              treat .smc2/.smc/.zip as binary: no diff, no merge, no line-ending changes
.github/pull_request_template.md   reviewer checklist
.github/CODEOWNERS          route reviews to the team lead
exports/, events/, media/, docs/   reserved for Phase 2 (export watcher and event log)
```

## Usage

Requires Git and Windows PowerShell 5.1+ (also tested on PowerShell 7).

```powershell
# Optional: Teams incoming webhook URL for notifications
$env:SYNCALERT_WEBHOOK = "https://..."

# Before opening the project in Sysmac Studio
.\tools\lock-start.ps1 "adding conveyor stop rung"

# ...edit, export, commit the export...

# When you're done
.\tools\lock-end.ps1 "added conveyor stop rung, tested in sim"
```

Both scripts take `-Project` (default `SyncAlert`) for repos with more than one Sysmac project. `lock-end.ps1` only lets the person who holds the lock release it, unless you pass `-Force`. That's useful when someone forgets and goes home.

Without `SYNCALERT_WEBHOOK` set, everything still works. The Teams post is just skipped.

## Recovering from a bad push

Roll `main` back to the last weekly tag:

```bash
git fetch --all --tags
git checkout main
git reset --hard <last-good-tag>
git push --force-with-lease
```

`--force-with-lease` refuses to overwrite the remote if someone pushed in the meantime. Branch protection on `main` has to allow this, so it's a team-lead action.

## Testing

Before writing the scripts, I used two GitHub accounts as "Engineer A" and "Engineer B" to commit to a real Sysmac project (simple start/stop motor ladder logic). That confirmed how Git handles `.smc2` files and why merging them isn't an option.

I then ran the lock scripts end to end, including the Teams notifications. The commit history on this repo shows those test runs. I also ran a two-clone simulation where the second user is blocked while a lock is held, can't release someone else's lock, and can lock from a brand-new branch.

## Roadmap

- **Phase 2:** a watcher that detects a new Sysmac export, commits it automatically, and posts `[EXPORT]` with the filename to Teams.
- Show stale locks (held more than N hours) in Teams so they don't block the team overnight.
