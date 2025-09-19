#!/bin/bash

# Setup GitHub Branch Protection using Terraform
# This script helps you configure branch protection for your repository

set -e

echo "🚀 Setting up GitHub Branch Protection with Terraform"
echo "=================================================="

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install Terraform first."
    echo "   Visit: https://www.terraform.io/downloads.html"
    exit 1
fi

# Check if we're in the right directory
if [ ! -d "terraform/github-branch-protection" ]; then
    echo "❌ Please run this script from the repository root directory"
    exit 1
fi

# Navigate to terraform directory
cd terraform/github-branch-protection

echo "📁 Working directory: $(pwd)"

# Check for GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  GITHUB_TOKEN environment variable not set."
    echo ""
    echo "🔑 You need a GitHub Personal Access Token with 'repo' permissions"
    echo "   Create one at: https://github.com/settings/tokens"
    echo ""
    echo "💡 Set the token as an environment variable:"
    echo "   export GITHUB_TOKEN=ghp_your_token_here"
    echo ""
    echo "🔒 Or run with the token inline (not recommended for production):"
    echo "   GITHUB_TOKEN=ghp_your_token_here ./scripts/setup-branch-protection.sh"
    echo ""
    read -p "Press Enter when you've set the GITHUB_TOKEN environment variable..."
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "📝 Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "✅ terraform.tfvars created (no sensitive data included)"
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "🔍 Validating Terraform configuration..."
terraform validate

# Plan the changes
echo "📋 Planning Terraform changes..."
terraform plan

echo ""
echo "✅ Terraform configuration is ready!"
echo ""
echo "🚀 To apply the branch protection rules, run:"
echo "   terraform apply"
echo ""
echo "📖 To see what will be created, run:"
echo "   terraform plan"
echo ""
echo "🗑️  To remove the protection rules, run:"
echo "   terraform destroy"
echo ""
echo "🎯 The branch protection will enforce:"
echo "   • PR reviews required (1 approval)"
echo "   • CI must pass (CI and Test Runner workflows)"
echo "   • Admin enforcement enabled"
echo "   • Conversation resolution required"
echo "   • Force pushes and deletions disabled"
