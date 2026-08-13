# Parallel Agents — one repo, many agents, no stomping

Many agent sessions (separate Claude Code instances, headless/cron jobs) run
against this repo on the same box. They share **one working tree**, and that is
the whole problem: git's index and your uncommitted edits are a *single* mutable
area. "Different branch" does not protect them — a checkout, a `git restore`, a
`git clean`, or a build/deploy that reads the live tree all operate on that one
area. So one agent sees another's half-written files (and panics), or wipes them
outright.

The fix is to make "the working tree" **plural**: one isolated worktree +
branch per agent, each with its own runnable, collision-free environment. The
shared `.git` keeps this cheap — no re-clones.

## The rule

**Never edit, build, or deploy from the main checkout.** Always work in a
per-agent worktree. The `guard-edit.sh` hook mechanically enforces the *edit*
half — an Edit/Write in the main checkout is blocked with the command to create
a worktree. The build/deploy half is enforced separately: per-worktree `target/`
and env (below) and `guard-bash.sh` (blocks destructive git + raw box sync).

## Daily workflow

```bash
# Create (or re-attach to) an isolated worktree for your task.
# Branch off development; prints the path. cd into it.
cd "$(scripts/agent-wt.sh new feature/GH-123-add-thing)"
#   or: make agent slug=feature/GH-123-add-thing

# You're now in a private worktree with a generated .env (own PORT + state).
make run             # binds this worktree's PORT, not anyone else's
git commit ...       # uncommitted work lives only here — nothing else can see it
git push -u origin feature/GH-123-add-thing

# When the branch is pushed / merged:
make agent-rm slug=feature/GH-123-add-thing   # removes worktree, frees the slot
```

Housekeeping:

```bash
make agents      # list worktrees: slug, slot, branch, clean/dirty
make agent-gc    # prune registry rows whose directory was deleted by hand
```

## What gets isolated, and how

| Resource | Mechanism |
|---|---|
| Uncommitted code | Separate working tree per agent (outside the repo, under `$HOME/.worktrees/<repo>/<slug>`). Structurally unshareable. |
| Build artifacts | Each worktree keeps its **own** `./target` (no `cargo` build-lock contention) and they **share** an sccache cache (`.cargo/config.toml`), so a fresh worktree skips the cold rebuild. |
| Service port | `PORT = 8800 + slot`. |
| Service-specific state | `STATE_DIR` under `<worktree>/.worktree-state/`; add your own per-slot vars (DB name, Redis port, …) in `write_env()` of `scripts/agent-wt.sh`. |

`slot` is a stable 0..63 index assigned per worktree from a lock-guarded
registry (`$HOME/.worktrees/<repo>/.registry`), so two agents on the same box
can never derive the same port. The generated `.env` is gitignored — it never
rides a commit out of the worktree.

## Headless / cron / CI jobs

Background jobs (a scheduled task, a scripted build) must not touch the live
checkout either. Run them in a throwaway worktree pinned to a **committed ref** —
it physically cannot see or destroy uncommitted work:

```bash
scripts/with-ephemeral-worktree.sh development -- make check
scripts/with-ephemeral-worktree.sh "$GIT_SHA"  -- ./scripts/some-job.sh
```

## Adapting per service

`scripts/agent-wt.sh`'s `write_env()` emits a generic `.env` (`SERVICE_NAME`,
`PORT`, `COMPOSE_PROJECT_NAME`, `STATE_DIR`). Add the env your service needs —
each derived from `$slot` to stay collision-free — in the marked block. To
protect deploy boxes from a stale-tree `rsync`/`scp`, set `GUARD_DEPLOY_BOXES`
(an extended-regex of your hosts) for `guard-bash.sh`.

## Why not just separate clones / containers?

Worktrees share `.git` (cheap, instant) while giving full working-tree
isolation — the right weight for "many short-lived agent branches on one box."
Containers add total isolation but cost setup time and a Docker dependency for
every agent; full clones duplicate `.git` and waste disk. Worktrees + sccache +
per-slot resources get the isolation without those costs.
