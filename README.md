# template-rust-repo

The Sc0red Rust service template — the same quality apparatus as
`template-python-repo`, expressed in Rust, plus worked examples of the design
patterns every service reuses. Create a new repo from this template, rename the
crate, and start with the guardrails already in place.

## What you get

- **Strict, mechanical quality gates.** `cargo clippy -- -D warnings` (forbid
  `unsafe`; deny `unwrap`/`expect`/`panic`/`as`; deny clippy-`all`; warn pedantic
  + missing-docs), `rustfmt`, a **90% line-coverage gate** (`cargo llvm-cov`),
  supply-chain checks (`cargo deny` + `cargo audit`), and naming/skip-comment
  checks — wired into `make check-all`, pre-commit hooks, and CI.
- **Documented GoF patterns as living code:** error hierarchy (Template Method +
  Registry), retry (Strategy + Decorator), TTL cache, logging (Factory +
  Singleton-state), and the canonical Strategy + Registry structure
  (`src/strategies/signature/`). See `docs/design-patterns-guide.md`.
- **Spec-driven development** via OpenSpec (`openspec/specs/`, `/opsx:*` commands).
- **4-branch multi-environment delivery** (`development` → `testing` → `demo` →
  `production`) with environment-gated deploys.

## Prerequisites

- Rust toolchain (pinned in `rust-toolchain.toml`) via [rustup](https://rustup.rs).
- `make`, plus the tools in the `Brewfile`: `brew bundle` installs
  `cargo-llvm-cov`, `cargo-deny`, `cargo-audit`, `sonar-scanner`, `coderabbit`,
  `1password-cli`, `gh`, `jq`.

## Quick start

```bash
brew bundle                  # install tooling
rustup show                  # install the pinned toolchain + components
pre-commit install --install-hooks
make check                   # lint + test + security + naming
```

## Commands

| Command | Runs |
|---|---|
| `make format` | `cargo fmt` + `cargo clippy --fix` |
| `make lint` | clippy (`-D warnings`) + format check |
| `make test` | `cargo llvm-cov`, 90% line gate |
| `make security` | `cargo deny check` + `cargo audit` |
| `make naming` | abbreviation / skip-comment / file-name / branch-name checks |
| `make check` | lint + test + security + naming |
| `make check-all` | `check` + SonarCloud (required before commit) |
| `make sync-template` | pull improvements from this template |

See `CLAUDE.md` for standards and `docs/` for the detailed guides.
