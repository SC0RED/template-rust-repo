# AGENTS.md

Tool-agnostic guide for AI coding agents. Mirrors `CLAUDE.md`; keep them in sync.

## Build / test / lint

```bash
cargo build                              # build
make check                               # lint + test + security + naming
make test                                # cargo llvm-cov, 90% line coverage gate
cargo clippy --all-targets -- -D warnings  # lint (warnings are errors)
cargo fmt --all                          # format
```

## Architecture (≤10 lines)

A Rust service template. Library crate (`src/lib.rs`) holds all logic; `src/main.rs`
is a thin binary. Modules are worked examples of reused patterns: `error/`
(error hierarchy), `util/` (retry, TTL cache), `logging/`, `strategies/`
(the canonical trait + registry structure). Dependencies flow inward:
entry point → services → domain → types; infrastructure adapters implement
domain traits. Behavior is specified in `openspec/specs/`.

## File organization

- One responsibility per file; descriptive names (no `utils.rs`/`helpers.rs`).
- Each module dir with >3 files has a `README.md`.
- Files < 300 lines, functions < 50 lines, ≤ 3 positional params.

## Key constraints

- No `unsafe`, no `unwrap`/`expect`/`panic!` outside tests, no `as` casts, no `#[allow(...)]`.
- Fail fast: no defensive fallbacks; validate external input at the boundary, trust internal data.
- Public items need doc comments and explicit return types.
- Branch names: `{feature|bugfix|hotfix|chore|docs|refactor|test}/{TICKET-ID}-{description}`.
