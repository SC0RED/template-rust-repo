# System dependencies. Install with: brew bundle
# The Rust toolchain itself is managed by rustup (see rust-toolchain.toml):
#   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

brew "rustup"            # rustup-init; then `rustup show` installs the pinned toolchain
brew "cargo-llvm-cov"    # coverage (make test, 90% gate)
brew "cargo-deny"        # license + advisory + ban checks (make security)
brew "cargo-audit"       # dependency vulnerability audit (make security)
brew "sccache"           # shared compile cache across per-agent worktrees (.cargo/config.toml)
brew "sonar-scanner"     # SonarCloud analysis (make sonar)
brew "pre-commit"        # git hook runner
brew "gh"                # GitHub CLI
brew "jq"                # used by the Claude Code commit-gate hook
brew "git"

cask "1password-cli"     # secrets resolution (op) for make sonar / CI
cask "coderabbit"        # local AI review (make review)
