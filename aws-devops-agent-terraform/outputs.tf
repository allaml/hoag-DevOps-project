# Outputs for AWS DevOps Agent Configuration

output "agent_space_id" {
  description = "The ID of the created Agent Space"
  value       = awscc_devopsagent_agent_space.main.id
}

output "agent_space_arn" {
  description = "The ARN of the created Agent Space"
  value       = awscc_devopsagent_agent_space.main.arn
}

output "agent_space_name" {
  description = "The name of the created Agent Space"
  value       = awscc_devopsagent_agent_space.main.name
}

output "devops_agentspace_role_name" {
  description = "Name of the DevOps Agent Space IAM role"
  value       = aws_iam_role.devops_agentspace.name
}

output "devops_agentspace_role_arn" {
  description = "ARN of the DevOps Agent Space IAM role"
  value       = aws_iam_role.devops_agentspace.arn
}

output "devops_operator_role_name" {
  description = "Name of the DevOps Operator App IAM role"
  value       = aws_iam_role.devops_operator.name
}

output "devops_operator_role_arn" {
  description = "ARN of the DevOps Operator App IAM role"
  value       = aws_iam_role.devops_operator.arn
}

output "primary_account_association_id" {
  description = "ID of the primary AWS account association"
  value       = awscc_devopsagent_association.primary_aws_account.id
}

output "external_account_association_ids" {
  description = "IDs of external AWS account associations"
  value       = { for k, v in awscc_devopsagent_association.external_aws_accounts : k => v.id }
}

output "external_account_role_arns" {
  description = "ARNs of cross-account roles (created via CloudFormation StackSet)"
  value = {
    for k, v in var.external_accounts : k => "arn:aws:iam::${k}:role/DevOpsAgentCrossAccountRole"
  }
}

output "operator_app_role_arn" {
  description = "ARN of the operator app role (for manual setup)"
  value       = aws_iam_role.devops_operator.arn
}

output "account_id" {
  description = "Current AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "auth_flow" {
  description = "Authentication flow for operator app"
  value       = var.auth_flow
}

# Instructions for manual steps
output "manual_setup_instructions" {
  description = "Instructions for completing the setup"
  value       = <<-EOT
    
    AWS DevOps Agent Setup Complete!
    
    Agent Space ID: ${awscc_devopsagent_agent_space.main.id}
    
    Manual Steps Required:
    
    1. Enable Operator App (if desired):
       aws devopsagent enable-operator-app \
         --agent-space-id ${awscc_devopsagent_agent_space.main.id} \
         --auth-flow ${var.auth_flow} \
         --operator-app-role-arn ${aws_iam_role.devops_operator.arn} \
         --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
         --region us-east-1
    
    2. For external accounts, create cross-account roles in each external account:
       - Use the trust policy with monitoring account: ${data.aws_caller_identity.current.account_id}
       - External ID: arn:aws:aidevops:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agentspace/${awscc_devopsagent_agent_space.main.id}
    
    3. Access the DevOps Agent console at:
       https://console.aws.amazon.com/devopsagent/
    
    4. CLI commands to verify setup:
       aws devopsagent list-agent-spaces --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" --region us-east-1
       aws devopsagent get-agent-space --agent-space-id ${awscc_devopsagent_agent_space.main.id} --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" --region us-east-1
  EOT
}