# Cross-Account Role Creation in External Accounts
# Updated by murthy on 02/02/2026
# 
# NOTE: For 10+ target accounts, use CloudFormation StackSets instead of Terraform.
# See: cloudformation/STACKSET_DEPLOYMENT_GUIDE.md
#
# This file is kept for backward compatibility with small deployments (1-3 accounts).
# For production with 50 accounts, set create_cross_account_roles = false and use StackSets.

# Trust policy for cross-account roles (used by CloudFormation StackSet template)
data "aws_iam_policy_document" "cross_account_trust" {
  for_each = var.external_accounts

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.devops_agentspace.arn]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["arn:aws:aidevops:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agentspace/${awscc_devopsagent_agent_space.main.id}"]
    }
  }
}

# Output trust policy for CloudFormation StackSet
output "cross_account_trust_policy" {
  description = "Trust policy for cross-account roles (use in CloudFormation StackSet)"
  value = length(var.external_accounts) > 0 ? {
    for k, v in data.aws_iam_policy_document.cross_account_trust : k => v.json
  } : {}
}
