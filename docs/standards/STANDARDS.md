# Engineering Standards

The standards every Sc0red Rust service follows. Most are enforced mechanically —
the table maps each rule to the tool that enforces it. Mechanical enforcement
always wins over prose.

## Enforcement map

| Standard | Enforced by |
|----------|-------------|
| Formatting | `rustfmt` (`make format`; CI runs `cargo fmt --check`) |
| No `unsafe` | `#![forbid(unsafe_code)]` lint in `Cargo.toml` |
| No `unwrap`/`expect`/`panic!` (non-test) | clippy `unwrap_used`/`expect_used`/`panic` = deny |
| No `as` casts | clippy `as_conversions` = deny (use `From`/`TryFrom`) |
| Clippy `all` clean, `pedantic` reviewed | `cargo clippy -- -D warnings` |
| Public items documented | `missing_docs` = warn → error under `-D warnings` |
| ≤ 3 positional params, ≤ 50-line fns, low complexity | `clippy.toml` thresholds |
| 90% line coverage | `cargo llvm-cov --fail-under-lines 90` |
| Supply chain (licenses, advisories, bans) | `cargo deny check` + `cargo audit` |
| No skip comments / abbreviations / generic file names | `scripts/check_*.sh` |
| Secrets never committed | `gitleaks` (pre-commit + CI) |
| Conventional Commits | `commitizen` (commit-msg hook) |
| Branch naming | `scripts/check_branch_name.sh` (pre-push) |

## Principles (the why behind the rules)

- **Fail fast, no defensive code.** Don't add fallbacks for internal invariants.
  Validate external input once at the boundary (serde); trust internal data.
- **Errors propagate to a boundary.** Build a `ServiceError`; render RFC 7807 at
  the handler/worker. Catch only to add context and rethrow.
- **Make illegal states unrepresentable.** Prefer enums + exhaustive `match` over
  runtime checks; let the compiler be the reviewer.
- **One responsibility per file.** Descriptive names; a module dir with >3 files
  carries a `README.md`.
- **Explicit over implicit.** Dependency injection over global state; typed
  constants over magic strings; registries over auto-discovery.

## Architecture

Dependencies flow inward: entry point → services → domain → types. Infrastructure
adapters implement domain-defined traits, never the reverse. The library crate
holds all logic; the binary is a thin wiring layer. Behavior is specified in
`openspec/specs/` and verified by tests.
