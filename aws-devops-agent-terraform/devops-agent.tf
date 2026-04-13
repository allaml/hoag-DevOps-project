# AWS DevOps Agent Resources

# Create the Agent Space
resource "awscc_devopsagent_agent_space" "main" {
  name        = var.agent_space_name
  description = var.agent_space_description

  depends_on = [
    aws_iam_role.devops_agentspace,
    aws_iam_role_policy_attachment.devops_agentspace_managed,
    aws_iam_role_policy.devops_agentspace_inline
  ]
}

# Wait for IAM role to be fully propagated
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role.devops_agentspace,
    aws_iam_role_policy_attachment.devops_agentspace_managed,
    aws_iam_role_policy.devops_agentspace_inline
  ]

  create_duration = "30s"
}

# Associate the primary AWS account for monitoring
resource "awscc_devopsagent_association" "primary_aws_account" {
  agent_space_id = awscc_devopsagent_agent_space.main.id
  service_id     = "aws"

  configuration = {
    aws = {
      assumable_role_arn = aws_iam_role.devops_agentspace.arn
      account_id         = data.aws_caller_identity.current.account_id
      account_type       = "monitor"
      resources          = []
    }
  }

  depends_on = [
    time_sleep.wait_for_iam_propagation
  ]
}

# Note: Operator App enablement is not supported by the AWSCC provider
# This must be done manually via AWS CLI or console after Terraform deployment
# See the manual_setup_instructions output for the CLI command