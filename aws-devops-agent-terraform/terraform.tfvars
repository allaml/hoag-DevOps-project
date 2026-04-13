# Example Terraform variables file
# Copy this to terraform.tfvars and customize as needed

# AWS region (must be us-east-1 for DevOps Agent)
aws_region = "us-east-1"

# Resource naming (optional - if not provided, random suffix will be used)
# name_postfix = "v2"

# Agent Space configuration
agent_space_name        = "ZayodevopsAgentSpace"
agent_space_description = "DevOps Agent Space for monitoring production workloads"

# Operator App configuration
enable_operator_app = true
auth_flow           = "iam" # or "idc" for Identity Center

# Added by murthy on 02/02/2026
# For 50 accounts, use CloudFormation StackSets (see cloudformation/ directory)
# Set create_cross_account_roles = false. This will Indicates we are not using terraform but instead of Terraform for cross-account roles we use CFS
create_cross_account_roles = false

# external_accounts = {}

# External AWS accounts to monitor
external_accounts = {
  "608649261817" = {
    account_id = "608649261817"
    role_arn   = ""
  }
  "295451572584" = {
    account_id = "295451572584"
    role_arn   = ""
  }
}

# Tags for all resources
tags = {
  Environment = "production"
  Project     = "aws-devops-agent"
  Owner       = "ccoe-team"
  APM_ID      = "engineering"
}
