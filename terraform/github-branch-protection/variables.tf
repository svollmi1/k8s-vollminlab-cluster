variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
  default     = "svollmi1"
}

variable "repository_name" {
  description = "Name of the GitHub repository"
  type        = string
  default     = "k8s-vollminlab-cluster"
}

variable "github_token" {
  description = "GitHub personal access token with repo permissions"
  type        = string
  sensitive   = true
  default     = null
}
