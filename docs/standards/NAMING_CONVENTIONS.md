# Naming Conventions

Most casing is enforced by the Rust compiler (`non_snake_case`,
`non_upper_case_globals`, …) and clippy. This doc records the conventions and the
few rules the `scripts/check_*.sh` checks enforce on top.

## Code

| Element | Convention | Example |
|---------|------------|---------|
| Types (struct/enum/trait) | PascalCase | `ServiceError`, `RetryConfig`, `SignatureStrategy` |
| Functions / methods | snake_case | `from_code`, `into_problem_details`, `verify` |
| Accessors | named for the field (no `get_` prefix) | `name()`, `len()`, `hits()` |
| Other functions | verb-first | `build_*`, `parse`, `init`, `retry` |
| Constants / statics | SCREAMING_SNAKE_CASE | `ALL`, `INITIALIZED` |
| Variables | snake_case | `error_message`, `retry_count` |
| Modules / files | snake_case | `ttl_cache.rs`, `error/mod.rs` |

**Idiomatic exception to verb-first:** Rust getters are named for the field they
return, not `get_field`. clippy actively discourages the `get_` prefix, so
`name()`/`code()`/`len()` are correct, not violations.

## Forbidden

- **Generic file names** — `utils.rs`, `helpers.rs`, `common.rs`, `misc.rs`,
  `shared.rs`. Name the file for its responsibility (`retry.rs`, `ttl_cache.rs`).
  (`mod.rs` is exempt — it is Rust's module-root convention.)
- **Abbreviations** — use full words. Forbidden (conservative list, excludes
  Rust-colliding tokens like `cfg`/`impl`/`err`): `msg`, `req`, `resp`, `ctx`,
  `mgr`, `usr`, `pwd`, `tmp`, `temp`, `btn`. Extend per project in
  `scripts/check_abbreviations.sh`.

## Branches

`{type}/{TICKET-ID}-{description}` where type ∈ {feature, bugfix, hotfix, chore,
docs, refactor, test}; description is lowercase/digits/hyphens, 3–50 chars.
Example: `feature/SF-123-add-signature-strategy`. Enforced by
`scripts/check_branch_name.sh` (pre-push).
