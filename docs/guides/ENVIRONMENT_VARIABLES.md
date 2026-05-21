# Environment Variables

## Important: No .env Files!

**This project uses 1Password for all secrets.** There are no .env files. See [SECRETS_MANAGEMENT.md](./SECRETS_MANAGEMENT.md) for details.

## Variables Reference

| Variable | Description | Source |
|----------|-------------|--------|
| `SONAR_TOKEN` | SonarCloud authentication token | 1Password: `op://Engineering/SONAR_TOKEN/credential` |
| `AWS_PROFILE` | AWS CLI profile name | Your shell profile or AWS config |
| `AWS_REGION` | AWS region (default: us-east-1) | Your shell profile or AWS config |
| `GITHUB_TOKEN` | GitHub personal access token | 1Password (if needed) |

## How to Use

### For secrets (from 1Password):
```bash
# Automatic - Makefile handles it
make sonar  # Pulls SONAR_TOKEN automatically

# Manual - if needed
export SONAR_TOKEN=$(op read "op://Engineering/SONAR_TOKEN/credential")
```

### For AWS configuration:
```bash
# Set in your shell profile
export AWS_PROFILE=sc0red-dev
export AWS_REGION=us-east-1

# Or use AWS CLI
aws configure --profile sc0red-dev
```

## No .env Files!

- ❌ DON'T create `.env` files
- ❌ DON'T create `.env_development` files
- ❌ DON'T store secrets in files
- ✅ DO use 1Password for all secrets
- ✅ DO use Makefile targets that handle 1Password
- ✅ DO keep AWS config in AWS CLI profiles
