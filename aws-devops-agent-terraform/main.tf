# AWS DevOps Agent Terraform Configuration
# This configuration replicates the CLI onboarding guide setup
# Updated by murthy on 02/02/2026 - Optimized for CloudFormation StackSet approach

provider "awscc" {
  region = var.aws_region
}

provider "aws" {
  region = var.aws_region
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}