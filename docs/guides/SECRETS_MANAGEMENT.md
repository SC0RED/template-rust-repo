# Secrets Management with 1Password

## Overview

This project uses **1Password** for all secrets management. There are **NO .env files** - all secrets are pulled on-demand from 1Password.

## Why 1Password?

- ✅ **No .env files** to manage or accidentally commit
- ✅ **Tokens always fresh** from 1Password
- ✅ **Team sync** - update in 1Password, everyone gets it
- ✅ **Tokens never written to disk**
- ✅ **Audit trail** in 1Password
- ✅ **No environment juggling** - one source of truth

## Setup

### 1. Install 1Password CLI

```bash
# macOS
brew install --cask 1password-cli

# Linux/WSL
# Download from: https://developer.1password.com/docs/cli/get-started/
```

### 2. Sign in to 1Password

```bash
# First time setup
op signin

# Test access
op whoami
```

### 3. Verify vault access

```bash
# List available vaults
op vault list

# Test reading a secret
op read "op://Engineering/SONAR_TOKEN/credential"
```

## Required Secrets

All secrets are stored in the **Engineering** vault in 1Password:

| Secret Name | Description | Used By |
|-------------|-------------|---------|
| `SONAR_TOKEN` | SonarCloud authentication token | `make sonar`, CI/CD |
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password service account for CI/CD | GitHub Actions |

## Local Development

### Running SonarCloud Analysis

```bash
# The Makefile automatically pulls the token from 1Password
make sonar

# What happens behind the scenes:
# 1. Checks if 1Password CLI is installed
# 2. Signs in if needed
# 3. Fetches SONAR_TOKEN from Engineering vault
# 4. Runs sonar-scanner with the token
# 5. Token is never written to disk
```

### Manual Secret Access

If you need to access a secret manually:

```bash
# Read a secret
op read "op://Engineering/SONAR_TOKEN/credential"

# Use in a command
SONAR_TOKEN=$(op read "op://Engineering/SONAR_TOKEN/credential") some-command

# Export temporarily (current shell only)
export SONAR_TOKEN=$(op read "op://Engineering/SONAR_TOKEN/credential")
```

## CI/CD (GitHub Actions)

GitHub Actions use a 1Password Service Account:

```yaml
- name: Load secrets from 1Password
  uses: 1password/load-secrets-action@v2
  with:
    export-env: true
  env:
    OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
    SONAR_TOKEN: op://Engineering/SONAR_TOKEN/credential
```

## Adding New Secrets

1. Add to 1Password Engineering vault:
   ```bash
   op item create \
     --category=Password \
     --title="MY_NEW_SECRET" \
     --vault="Engineering" \
     credential=actual-secret-value
   ```

2. Update this documentation

3. Update Makefile if needed for local commands

4. Update GitHub Actions if needed for CI/CD

## Troubleshooting

### "1Password CLI not found"
```bash
brew install --cask 1password-cli
```

### "Could not read secret from 1Password"
- Check you're signed in: `op signin`
- Verify vault access: `op vault list`
- Check secret exists: `op item list --vault Engineering`

### "Session expired"
```bash
eval $(op signin)
```

## Migration from .env Files

If you're coming from .env files:

1. **DON'T create .env files** - they're not used
2. **DON'T export secrets permanently** - pull on-demand
3. **DO use the Makefile targets** - they handle 1Password for you
4. **DO keep secrets in 1Password only**

## Security Best Practices

- Never write secrets to files
- Never commit secrets to git
- Always use `op read` on-demand
- Rotate secrets regularly in 1Password
- Use service accounts for CI/CD
- Limit vault access to team members who need it
