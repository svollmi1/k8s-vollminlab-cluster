output "branch_protection_id" {
  description = "The ID of the branch protection rule"
  value       = github_branch_protection.main.id
}

output "repository_name" {
  description = "The name of the repository"
  value       = data.github_repository.repo.name
}

output "repository_url" {
  description = "The URL of the repository"
  value       = data.github_repository.repo.html_url
}
