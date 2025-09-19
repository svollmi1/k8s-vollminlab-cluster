terraform {
  required_version = ">= 1.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

# Configure the GitHub Provider
provider "github" {
  owner = var.github_owner
  token = var.github_token != null ? var.github_token : null
}

# Data source to get repository information
data "github_repository" "repo" {
  name = var.repository_name
}

# Branch protection rule for main branch
resource "github_branch_protection" "main" {
  repository_id = data.github_repository.repo.node_id
  
  pattern = "main"
  
  # Require status checks to pass before merging
  required_status_checks {
    strict   = true
    contexts = ["CI", "Test Runner"]
  }
  
  # Enforce branch protection rules for administrators
  enforce_admins = true
  
  # Require pull request reviews before merging
  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = false
    pull_request_bypassers          = []
  }
  
  # Require conversation resolution before merging
  require_conversation_resolution = true
  
  # Restrict pushes that create files larger than 100 MB
  push_restrictions = []
  
  # Allow force pushes (set to false for stricter protection)
  allows_force_pushes = false
  
  # Allow deletions (set to false for stricter protection)
  allows_deletions = false
}
