output "gitlab_association_id" {
  description = "ID of the GitLab association"
  value       = awscc_devopsagent_association.gitlab.id
}

output "gitlab_association_status" {
  description = "Status of the GitLab association"
  value       = awscc_devopsagent_association.gitlab.id != null ? "Created" : "Failed"
}

output "agent_space_id" {
  description = "Agent Space ID being used"
  value       = data.terraform_remote_state.devops_agent.outputs.agent_space_id
}
