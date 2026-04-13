# GitLab Integration for AWS DevOps Agent

This directory contains the GitLab integration configuration for AWS DevOps Agent. It's separated from the main infrastructure to allow independent lifecycle management.

## Prerequisites

1. **Main DevOps Agent deployed**: The parent directory must have a deployed Agent Space
2. **GitLab token**: Obtain from GitLab DevOps team with required scopes
3. **AWS credentials**: Configured for zayo-hub profile

## Setup Instructions

### Step 1: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:
- `gitlab_url`: Your GitLab instance URL
- `gitlab_token`: Token from GitLab team

### Step 2: Initialize Terraform

```bash
cd gitlab-integration
terraform init
```

### Step 3: Review Plan

```bash
terraform plan
```

### Step 4: Deploy

```bash
terraform apply
```

## Usage

### Deploy GitLab Integration
```bash
cd gitlab-integration
terraform apply
```

### Remove GitLab Integration
```bash
cd gitlab-integration
terraform destroy
```

### Update Configuration
```bash
# Edit terraform.tfvars
terraform apply
```

## Benefits of Separate Module

✅ **Independent lifecycle** - Main infrastructure changes don't affect GitLab integration
✅ **Safe testing** - Destroy/recreate main infrastructure without losing GitLab config
✅ **Isolated state** - Separate terraform.tfstate file
✅ **Easy rollback** - Can remove and redeploy GitLab integration independently

## GitLab Token Requirements

Request from GitLab DevOps team:
- **Service account**: `aws-devops-agent-bot@zayo.com`
- **Scopes**: `api`, `read_api`, `read_repository`, `read_user`
- **Access**: Projects/groups to monitor
- **Expiration**: 90 days or as per policy

## Verification

After deployment, verify in AWS Console:
1. Go to: https://console.aws.amazon.com/devopsagent/
2. Select Agent Space: `ZayodevopsAgentSpace`
3. Click "Associations" tab
4. Verify GitLab association shows "Active"

## Troubleshooting

**Error: Invalid token**
- Verify token has correct scopes
- Check token hasn't expired
- Ensure service account has project access

**Error: Agent Space not found**
- Ensure main DevOps Agent is deployed
- Check terraform.tfstate exists in parent directory

**Error: Permission denied**
- Verify AWS profile `zayo-hub` is configured
- Check IAM permissions for DevOps Agent

## Security

- Never commit `terraform.tfvars` with real token
- Store token in AWS Secrets Manager (recommended)
- Rotate token regularly
- Use minimum required scopes
