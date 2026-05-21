.PHONY: install lint lint-quick test check check-all format security naming sonar review dev run sync-template help

# Colors for output
BLUE := \033[0;34m
YELLOW := \033[0;33m
RED := \033[0;31m
GREEN := \033[0;32m
NC := \033[0m

# ═══════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════

install: ## Fetch dependencies (toolchain is pinned in rust-toolchain.toml)
	cargo fetch

# ═══════════════════════════════════════════════════════════════════════════
# LINTING & FORMATTING
# ═══════════════════════════════════════════════════════════════════════════

lint-quick: ## Quick lint (clippy, warnings = errors) — dev-server gate
	@echo "$(BLUE)Running clippy...$(NC)"
	cargo clippy --all-targets --all-features -- -D warnings
	@echo "$(GREEN)✅ Quick lint passed$(NC)"

lint: lint-quick ## Full lint (clippy + format check)
	cargo fmt --all --check
	@echo "$(GREEN)✅ Full lint passed$(NC)"

format: ## Auto-format and apply machine-applicable clippy fixes
	cargo fmt --all
	cargo clippy --fix --allow-dirty --allow-staged --all-targets --all-features
	@echo "$(GREEN)✅ Code formatted$(NC)"

# ═══════════════════════════════════════════════════════════════════════════
# TESTING (90% line coverage gate)
# ═══════════════════════════════════════════════════════════════════════════

test: ## Run tests with the 90% line-coverage gate (writes lcov.info for Sonar)
	cargo llvm-cov --all-features --workspace \
		--fail-under-lines 90 \
		--lcov --output-path lcov.info

# ═══════════════════════════════════════════════════════════════════════════
# SECURITY & NAMING
# ═══════════════════════════════════════════════════════════════════════════

security: ## Supply-chain audit (cargo-deny + cargo-audit)
	cargo deny check
	cargo audit

naming: ## Verb-prefix, abbreviation, skip-comment, and branch-name checks
	@echo "$(BLUE)Checking naming conventions...$(NC)"
	scripts/check_naming.sh
	scripts/check_abbreviations.sh
	scripts/check_skip_comments.sh
	scripts/check_branch_name.sh
	@echo "$(GREEN)✅ Naming checks passed$(NC)"

# ═══════════════════════════════════════════════════════════════════════════
# CODE QUALITY ANALYSIS
# ═══════════════════════════════════════════════════════════════════════════

# Token resolution order: an exported $SONAR_TOKEN wins; otherwise read it from
# 1Password using $SONAR_TOKEN_OP_REF (override per your vault layout). The token
# lives in the "Sonar Token" secure note (Engineering vault); reading it needs an
# op account that can see it (set OP_ACCOUNT if you have several).
SONAR_TOKEN_OP_REF ?= op://Engineering/Sonar Token/notesPlain

sonar: ## Run SonarCloud analysis ($SONAR_TOKEN, else read via $SONAR_TOKEN_OP_REF)
	@echo "$(BLUE)Running SonarCloud analysis...$(NC)"
	@command -v sonar-scanner >/dev/null 2>&1 || { \
		echo "$(RED)sonar-scanner not installed (brew install sonar-scanner)$(NC)"; exit 1; }
	@token="$$SONAR_TOKEN"; \
	if [ -z "$$token" ]; then \
		command -v op >/dev/null 2>&1 || { \
			echo "$(RED)Set SONAR_TOKEN, or install the 1Password CLI to read $(SONAR_TOKEN_OP_REF)$(NC)"; exit 1; }; \
		token=$$(op read "$(SONAR_TOKEN_OP_REF)" 2>/dev/null) || { \
			echo "$(RED)Could not read a token. Export SONAR_TOKEN, or point SONAR_TOKEN_OP_REF at your 1Password item.$(NC)"; exit 1; }; \
	fi; \
	SONAR_TOKEN=$$token sonar-scanner

# ═══════════════════════════════════════════════════════════════════════════
# AI CODE REVIEW
# ═══════════════════════════════════════════════════════════════════════════

review: ## AI code review via CodeRabbit (uncommitted changes)
	@if ! command -v coderabbit >/dev/null 2>&1; then \
		echo "$(RED)Error: CodeRabbit CLI not found (brew install --cask coderabbit)$(NC)"; exit 1; \
	fi
	coderabbit review --plain --type uncommitted
	@echo "$(GREEN)✅ AI review passed$(NC)"

# ═══════════════════════════════════════════════════════════════════════════
# COMBINED CHECKS
# ═══════════════════════════════════════════════════════════════════════════

check: lint test security naming ## Run ALL local checks (lint + test + security + naming)
	@echo "$(GREEN)✅ All local checks passed$(NC)"

check-all: check sonar ## Run all checks including SonarCloud (required before commit)
	@echo "$(GREEN)✅ All checks passed (including SonarCloud)$(NC)"

# ═══════════════════════════════════════════════════════════════════════════
# DEV / RUN
# ═══════════════════════════════════════════════════════════════════════════

dev: lint-quick ## Run with hot reload (cargo-watch); falls back to `cargo run`
	@if command -v cargo-watch >/dev/null 2>&1; then \
		cargo watch -x run; \
	else \
		echo "$(YELLOW)cargo-watch not installed (cargo install cargo-watch); running once$(NC)"; \
		cargo run; \
	fi

run: lint-quick ## Run the service (lint must pass first)
	cargo run

# ═══════════════════════════════════════════════════════════════════════════
# TEMPLATE SYNC
# ═══════════════════════════════════════════════════════════════════════════

sync-template: ## Pull latest changes from the upstream template repo
	@if ! git remote | grep -q template; then \
		git remote add template git@github.com:SC0RED/template-rust-repo.git; \
	fi
	git fetch template
	git merge template/development --no-edit
	@echo "$(GREEN)✅ Template sync complete — review, resolve conflicts, commit$(NC)"

# ═══════════════════════════════════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════════════════════════════════

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-14s$(NC) %s\n", $$1, $$2}'
