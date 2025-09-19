# GitHub Branch Protection Terraform Configuration

This Terraform configuration sets up branch protection rules for the main branch of your repository.

## Features

- ✅ **Requires PR reviews** (minimum 1 approval)
- ✅ **Requires CI to pass** (CI and Test Runner workflows)
- ✅ **Enforces admin protection** (even admins must follow rules)
- ✅ **Requires conversation resolution** before merging
- ✅ **Prevents force pushes** and deletions
- ✅ **Requires up-to-date branches** before merging

## Prerequisites

1. **GitHub Personal Access Token** with the following permissions:
   - `repo` (Full control of private repositories)
   - `admin:org` (if managing organization repositories)

2. **Terraform** installed (version >= 1.0)

## Setup

1. **Create GitHub Token:**
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate new token with `repo` scope
   - Copy the token

2. **Set Environment Variable:**
   ```bash
   export GITHUB_TOKEN=ghp_your_token_here
   ```

3. **Configure Terraform:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars contains no sensitive data
   ```

4. **Initialize and Apply:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## 🔒 Security Notes

- **NEVER commit tokens to version control**
- **Use environment variables** for sensitive data
- **GitHub Actions** automatically provides `GITHUB_TOKEN` secret
- **terraform.tfvars** is gitignored and contains no secrets

## Configuration

The branch protection rule enforces:

- **Branch Pattern:** `main`
- **Required Status Checks:** `CI`, `Test Runner`
- **Required Reviews:** 1 approval
- **Admin Enforcement:** Yes (admins must follow rules)
- **Conversation Resolution:** Required
- **Force Push:** Disabled
- **Deletions:** Disabled

## Integration with GitOps

This configuration can be integrated into your Flux GitOps workflow by:

1. **Adding to your cluster configuration**
2. **Running via GitHub Actions** (using Terraform action)
3. **Managing as part of your infrastructure**

## Security Notes

- Store your GitHub token securely (use GitHub Secrets in Actions)
- Consider using GitHub App authentication for production
- Review and adjust permissions based on your security requirements
