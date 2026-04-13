# Variables for AWS DevOps Agent Configuration

variable "aws_region" {
  description = "AWS region for DevOps Agent (must be us-east-1)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "AWS DevOps Agent is only available in us-east-1 region."
  }
}

variable "agent_space_name" {
  description = "Name for the DevOps Agent Space"
  type        = string
  default     = "MyAgentSpace"
}

variable "agent_space_description" {
  description = "Description for the DevOps Agent Space"
  type        = string
  default     = "AgentSpace for monitoring my application"
}

variable "enable_operator_app" {
  description = "Whether to enable the operator app"
  type        = bool
  default     = true
}

variable "auth_flow" {
  description = "Authentication flow for operator app (iam or idc)"
  type        = string
  default     = "iam"

  validation {
    condition     = contains(["iam", "idc"], var.auth_flow)
    error_message = "Auth flow must be either 'iam' or 'idc'."
  }
}

variable "external_accounts" {
  description = "Map of external AWS accounts to associate (optional). Key is account ID, value is role ARN for cross-account access."
  type = map(object({
    account_id = string
    role_arn   = string
  }))
  default = {}
}

variable "create_cross_account_roles" {
  description = "DEPRECATED: Use CloudFormation StackSets for 10+ accounts. See cloudformation/STACKSET_DEPLOYMENT_GUIDE.md"
  type        = bool
  default     = false
}

variable "name_postfix" {
  description = "Postfix for resource names to ensure uniqueness"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "aws-devops-agent"
  }
}