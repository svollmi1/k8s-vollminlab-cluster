resource "harbor_robot_account" "github_actions" {
  name        = "github-actions"
  description = "GitHub Actions image push robot (vollminlab project)"
  level       = "project"
  secret      = var.harbor_gha_robot_secret
  duration    = -1

  permissions {
    kind      = "project"
    namespace = "vollminlab"

    access {
      action   = "push"
      resource = "repository"
      effect   = "allow"
    }

    access {
      action   = "pull"
      resource = "repository"
      effect   = "allow"
    }
  }
}

output "gha_robot_full_name" {
  description = "Full Harbor username for the github-actions robot account"
  value       = harbor_robot_account.github_actions.full_name
  sensitive   = false
}

resource "harbor_robot_account" "cluster_pull" {
  name        = "cluster-pull"
  description = "In-cluster image pull robot (read-only, vollminlab project)"
  level       = "project"
  secret      = var.harbor_cluster_pull_secret
  duration    = -1

  permissions {
    kind      = "project"
    namespace = "vollminlab"

    access {
      action   = "pull"
      resource = "repository"
      effect   = "allow"
    }
  }
}

output "cluster_pull_robot_full_name" {
  description = "Full Harbor username for the cluster-pull robot account"
  value       = harbor_robot_account.cluster_pull.full_name
  sensitive   = false
}
