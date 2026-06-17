# CLAUDE.md — Sc0red Rust Service Standards

## Before completing any task

```bash
make check-all   # lint + test + security + naming + SonarCloud — all must pass
```

After pushing a PR, address every CodeRabbit comment (`gh pr view --comments`).

## Forbidden (enforced by `cargo clippy -- -D warnings` + hooks)

- `unsafe` code; `unwrap()` / `expect()` / `panic!` in non-test code; `as` casts
- `#[allow(...)]` and other skip comments — fix the issue, never silence it
- Defensive code / silent fallbacks — fail fast; let errors reach a boundary
- Files > 300 lines, functions > 50 lines, > 3 positional params (use a struct)
- Generic file names (`utils.rs`, `helpers.rs`) — name for the responsibility

## Conventions

- Never edit/build/deploy from the main checkout — one worktree per agent (`make agent slug=…`; see `docs/guides/PARALLEL_AGENTS.md`)
- Validate external input at the boundary (serde); trust internal data
- Public items need `///` docs and explicit return types
- Errors: build a `ServiceError`, let it propagate; render RFC 7807 at the boundary
- Add a strategy/runner by implementing its trait + registering it — nothing else
- `unwrap`/`expect` are allowed in `#[cfg(test)]` only (configured in `clippy.toml`)

## Where things are

| Thing | Location |
|---|---|
| Error hierarchy (Template Method + Registry) | `src/error/` |
| Retry (Strategy + Decorator), TTL cache | `src/util/` |
| Logging (Factory + Singleton-state) | `src/logging/` |
| Strategy + Registry reference structure | `src/strategies/signature/` |
| Patterns guide | `docs/design-patterns-guide.md` |
| Standards / branching / secrets | `docs/` |
| Behavior specs | `openspec/specs/` |

## Commands

```bash
make format   # cargo fmt + clippy --fix
make check    # lint + test + security + naming
make test     # cargo llvm-cov, 90% line gate
```

Detail lives in `docs/`. Keep this file under 60 lines — mechanical enforcement
(clippy, hooks, CI) always takes precedence over instructions here.
