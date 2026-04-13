variable "gitlab_url" {
  description = "GitLab instance URL (e.g., https://gitlab.zayo.com or https://gitlab.com)"
  type        = string
  default     = "https://gitlab.com"
}

variable "gitlab_token" {
  description = "GitLab personal access token with api, read_api, read_repository scopes"
  type        = string
  sensitive   = true
}
