.PHONY: install lint lint-quick test check check-all format security naming gates sonar review dev run sync-template sync-standards help agent agents agent-rm agent-gc

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
# PARALLEL AGENTS — isolated worktrees (docs/guides/PARALLEL_AGENTS.md)
# ═══════════════════════════════════════════════════════════════════════════

agent: ## Create/attach an isolated worktree + env: make agent slug=feature/GH-1-x [base=development]
	@test -n "$(slug)" || { echo "Usage: make agent slug=<branch> [base=<branch>]"; exit 1; }
	@scripts/agent-wt.sh new "$(slug)" $(base)

agents: ## List per-agent worktrees (slot, branch, clean/dirty)
	@scripts/agent-wt.sh ls

agent-rm: ## Remove a worktree and free its slot: make agent-rm slug=<branch|slug> [force=-f]
	@test -n "$(slug)" || { echo "Usage: make agent-rm slug=<branch|slug> [force=-f]"; exit 1; }
	@scripts/agent-wt.sh rm "$(slug)" $(force)

agent-gc: ## Prune worktree registry entries whose directory is gone
	@scripts/agent-wt.sh gc

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

gates: ## Spec-catalog gates (specs valid, error boundaries, test seams, migrations, mocking, blast radius)
	@echo "$(BLUE)Running spec-catalog gates...$(NC)"
	@command -v openspec >/dev/null 2>&1 \
		&& openspec validate --specs --strict \
		|| echo "$(YELLOW)openspec not installed — skipping spec validation$(NC)"
	scripts/check_error_boundaries.sh
	scripts/check_test_seams.sh
	scripts/check_migrations.sh
	scripts/check_mocking.sh
	scripts/check_blast_radius.sh
	scripts/check_failure_coverage.sh
	scripts/check_project_context.sh
	scripts/check_agent_instructions.sh
	scripts/check_module_orientation.sh
	scripts/check_file_size.sh
	scripts/check_import_effects.sh
	@echo "$(GREEN)✅ Catalog gates passed$(NC)"

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

check: lint test security naming gates ## Run ALL local checks (lint + test + security + naming + gates)
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
# STANDARDS SYNC
# ═══════════════════════════════════════════════════════════════════════════

# The commit of SC0RED/sc0red-standards that openspec/specs/ is vendored from.
# To take a newer catalog: bump this, run `make sync-standards`, commit both the
# bump and the spec changes. Never hand-edit a vendored spec — fix it upstream.
STANDARDS_REPO ?= git@github.com:SC0RED/sc0red-standards.git
STANDARDS_REF  ?= 693d3f583ac9b84b6d10299b8c079911c8d3d017

sync-standards: ## Re-vendor openspec/specs/ from sc0red-standards at STANDARDS_REF
	@echo "$(BLUE)Syncing specs from sc0red-standards@$(STANDARDS_REF)...$(NC)"
	@tmp=$$(mktemp -d) || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT; \
	git clone --quiet --no-checkout "$(STANDARDS_REPO)" "$$tmp" || { \
		echo "$(RED)Could not clone $(STANDARDS_REPO)$(NC)"; exit 1; }; \
	git -C "$$tmp" checkout --quiet "$(STANDARDS_REF)" || { \
		echo "$(RED)Ref $(STANDARDS_REF) not found in $(STANDARDS_REPO)$(NC)"; exit 1; }; \
	test -d "$$tmp/specs" || { \
		echo "$(RED)No specs/ directory at $(STANDARDS_REF)$(NC)"; exit 1; }; \
	for dir in "$$tmp"/specs/*/; do \
		domain=$$(basename "$$dir"); \
		test -f "$$dir/spec.md" || continue; \
		mkdir -p "openspec/specs/$$domain"; \
		cp "$$dir/spec.md" "openspec/specs/$$domain/spec.md"; \
		echo "  synced $$domain"; \
	done; \
	for dir in openspec/specs/*/; do \
		domain=$$(basename "$$dir"); \
		test -d "$$tmp/specs/$$domain" || \
			echo "$(YELLOW)  $$domain is vendored here but absent upstream — delete it or move it upstream$(NC)"; \
	done
	@echo "$(GREEN)✅ Specs synced — review the diff, then commit$(NC)"

# ═══════════════════════════════════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════════════════════════════════

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-14s$(NC) %s\n", $$1, $$2}'
