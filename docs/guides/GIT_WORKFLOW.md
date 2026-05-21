# Git Workflow

## Branch model

Four long-lived branches map to environments; there is no `main`:

```
development → testing → demo → production
```

Work happens on `{type}/{TICKET-ID}-{description}` branches off `development` and
is promoted upward via PR. Direct pushes to the environment branches are blocked
(pre-commit hook locally, branch protection on the remote).

| Branch | Approvals | Admin enforced |
|--------|-----------|----------------|
| `development` | 0 | no |
| `testing` | 2 | yes |
| `demo` | 2 | yes |
| `production` | 3 + CODEOWNERS | yes |

## Setup scripts

| Script | Purpose |
|--------|---------|
| `scripts/initialize_branches.sh` | Create the four branches and set `development` as default |
| `scripts/setup-branch-protection.sh` | Apply branch-protection rules per the table above |
| `scripts/push-all-branches.sh` | Push all four environment branches |

After the first CI run, add the reusable-workflow check contexts (e.g.
`CI / Lint`, `CI / Test`, `CI / Security`, `CI / SonarCloud`, `Naming / Naming Summary`)
to each branch's required status checks.

## Bot identity (AI-authored commits)

Claude Code commits as the GitHub App bot so bot authorship is distinct from a
human developer. The credentials live in the 1Password Engineering vault.

```bash
./scripts/generate_github_app_token.sh   # mint a short-lived installation token
./scripts/git_push_as_bot.sh             # push the current branch as the bot
```

The `.claude` pre-commit gate requires the bot identity and `make check-all`
before any commit; the post-push hook requires checking CodeRabbit afterward.
Always open PRs — never push directly to an environment branch.
