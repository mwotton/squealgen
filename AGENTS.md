# Agent Notes

- On Ubuntu installs, `initdb` usually isn't on the default `PATH`; look for it under `/usr/lib/postgresql/<version>/bin/initdb` (e.g. `/usr/lib/postgresql/17/bin/initdb`).
- Always run the full test suite (`cabal test --test-show-details=direct`) before committing or pushing changes.

## Issue-Fix Workflow

- When fixing an issue, first write a failing test that reproduces the problem.
- Commit only the failing test, then open/push a PR so CI shows the failure.
- Implement the fix in a separate commit and push it to the same PR so CI shows the fix.
- If the initial failing test didn’t capture the failure correctly, it’s okay to amend/force-push the failing commit. The goal is to have two separate pushes so both the failing state and the fix are evidenced.
- Continue to run `cabal test --test-show-details=direct` locally before each push.

<!-- bv-agent-instructions-v1 -->

---

## Beads Workflow Integration

This project uses [beads_rust](https://github.com/Dicklesworthstone/beads_rust) for issue tracking. Issues are stored in `.beads/` and tracked in git.

**Note:** `br` is non-invasive and never executes git commands. After `br sync --flush-only`, you must manually run `git add .beads/ && git commit`.

### Essential Commands

```bash
# View issues (launches TUI - avoid in automated sessions)
bv

# CLI commands for agents (use these instead)
br ready              # Show issues ready to work (no blockers)
br list --status=open # All open issues
br show <id>          # Full issue details with dependencies
br create --title="..." --type=task --priority=2
br update <id> --status=in_progress
br close <id> --reason="Completed"
br close <id1> <id2>  # Close multiple issues at once
br sync --flush-only  # Export JSONL only; does not run git
git add .beads/
git commit -m "sync beads"
```

### Workflow Pattern

1. **Start**: Run `br ready` to find actionable work
2. **Claim**: Use `br update <id> --status=in_progress`
3. **Work**: Implement the task
4. **Complete**: Use `br close <id>`
5. **Sync**: Always run `br sync --flush-only` and commit `.beads/` at session end

### Key Concepts

- **Dependencies**: Issues can block other issues. `br ready` shows only unblocked work.
- **Priority**: P0=critical, P1=high, P2=medium, P3=low, P4=backlog (use numbers, not words)
- **Types**: task, bug, feature, epic, question, docs
- **Blocking**: `br dep add <issue> <depends-on>` to add dependencies

### Session Protocol

**Before ending any session, run this checklist:**

```bash
git status              # Check what changed
git add <files>         # Stage code changes
br sync --flush-only    # Export beads changes (JSONL only)
git add .beads/
git commit -m "sync beads"
git commit -m "..."     # Commit code
br sync --flush-only    # Export any new beads changes
git add .beads/
git commit -m "sync beads"
git push                # Push to remote
```

### Best Practices

- Check `br ready` at session start to find available work
- Update status as you work (in_progress → closed)
- Create new issues with `br create` when you discover tasks
- Use descriptive titles and set appropriate priority/type
- Always `br sync --flush-only` and commit `.beads/` before ending session
