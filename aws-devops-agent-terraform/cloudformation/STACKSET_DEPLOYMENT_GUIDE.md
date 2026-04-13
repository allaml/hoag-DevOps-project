# CloudFormation StackSet Deployment Guide
## Created by murthy on 02/02/2026

## Overview

This guide explains how to deploy cross-account IAM roles to 50+ target accounts using AWS CloudFormation StackSets from the AWS Console.

## Prerequisites

### 1. Deploy Terraform First (Monitoring Account)
```bash
cd /Users/mv2s/Desktop/Zayo-work/devOps-Agent-project/aws-devops-agent-terraform

# Set create_cross_account_roles = false in terraform.tfvars
terraform apply
```

### 2. Get Required Values
```bash
# Save these values - you'll need them for StackSet parameters
MONITORING_ACCOUNT_ID=$(terraform output -raw account_id)
AGENT_SPACE_ROLE_ARN=$(terraform output -raw devops_agentspace_role_arn)
AGENT_SPACE_ARN=$(terraform output -raw agent_space_arn)

echo "Monitoring Account ID: $MONITORING_ACCOUNT_ID"
echo "Agent Space Role ARN: $AGENT_SPACE_ROLE_ARN"
echo "Agent Space ARN: $AGENT_SPACE_ARN"
```

### 3. AWS Organizations Setup
- You must have AWS Organizations enabled
- Target accounts must be in your organization
- You need StackSet execution permissions

## Deployment Steps (AWS Console)

### Step 1: Navigate to CloudFormation StackSets

1. Log into AWS Console in your **monitoring account** (414351351247 - zayo-ct)
2. Go to **CloudFormation** service
3. Click **StackSets** in the left navigation
4. Click **Create StackSet**

### Step 2: Upload Template

1. Choose **Template is ready**
2. Choose **Upload a template file**
3. Click **Choose file** and select: `cloudformation/cross-account-role-stackset.yaml`
4. Click **Next**

### Step 3: Specify StackSet Details

**StackSet name:** `DevOpsAgent-CrossAccountRoles`

**Parameters:**
- **MonitoringAccountId**: `414351351247` (from terraform output)
- **AgentSpaceRoleArn**: `arn:aws:iam::414351351247:role/DevOpsAgentRole-AgentSpace-XXXXX` (from terraform output)
- **AgentSpaceArn**: `arn:aws:aidevops:us-east-1:414351351247:agentspace/XXXXX` (from terraform output)

Click **Next**

### Step 4: Configure StackSet Options

**Execution configuration:**
- Choose: **Service-managed permissions** (if using AWS Organizations)
- Or: **Self-managed permissions** (if you have pre-configured IAM roles)

**Tags (optional):**
- Key: `Project`, Value: `aws-devops-agent`
- Key: `ManagedBy`, Value: `CloudFormation-StackSet`
- Key: `CreatedBy`, Value: `murthy`

Click **Next**

### Step 5: Set Deployment Targets

**Deployment targets:**
- Choose: **Deploy to organization** (recommended)
- Or: **Deploy to organizational units (OUs)**
- Or: **Deploy to accounts** (specify all 50 account IDs)

**Account filter type:**
- If using OUs: Select the OU containing your 50 target accounts
- If using accounts: Enter comma-separated list of 50 account IDs

**Regions:**
- Select: **us-east-1** (only region needed for DevOps Agent)

**Deployment options:**
- **Maximum concurrent accounts**: `10` (deploys to 10 accounts at a time)
- **Failure tolerance**: `5` (continues if up to 5 accounts fail)
- **Region Concurrency**: Sequential

Click **Next**

### Step 6: Review and Create

1. Review all settings
2. Check the acknowledgment box: "I acknowledge that AWS CloudFormation might create IAM resources"
3. Click **Submit**

### Step 7: Monitor Deployment

1. StackSet will appear in the list with status **RUNNING**
2. Click on the StackSet name to see details
3. Go to **Stack instances** tab to see per-account status
4. Deployment typically takes 5-10 minutes for 50 accounts

## Verification

### Check StackSet Status
```bash
aws cloudformation describe-stack-set \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --region us-east-1 \
  --profile zayo-ct
```

### List All Stack Instances
```bash
aws cloudformation list-stack-instances \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --region us-east-1 \
  --profile zayo-ct
```

### Verify Role in a Target Account
```bash
# Switch to target account profile
aws iam get-role \
  --role-name DevOpsAgentCrossAccountRole \
  --profile <target-account-profile>
```

## Update Terraform Configuration

After StackSet deployment completes:

### 1. Update terraform.tfvars

```hcl
# Add all 50 target accounts
external_accounts = {
  "608649261817" = {
    account_id = "608649261817"
    role_arn   = "arn:aws:iam::608649261817:role/OrganizationAccountAccessRole"
  }
  "123456789012" = {
    account_id = "123456789012"
    role_arn   = "arn:aws:iam::123456789012:role/OrganizationAccountAccessRole"
  }
  # ... add all 50 accounts
}
```

### 2. Apply Terraform to Create Associations

```bash
terraform apply
```

This will create the DevOps Agent associations for all 50 accounts.

## Troubleshooting

### StackSet Fails to Deploy

**Issue:** "Insufficient permissions"
- **Solution:** Ensure you have `AWSCloudFormationStackSetAdministrationRole` in monitoring account
- **Solution:** Ensure target accounts have `AWSCloudFormationStackSetExecutionRole`

**Issue:** "Role already exists"
- **Solution:** Delete existing roles in target accounts or use update operation

### Stack Instance Fails

1. Go to StackSet → Stack instances
2. Find failed instances
3. Click on Account ID to see error details
4. Fix the issue in that account
5. Click **Actions** → **Retry** for failed instances

### Verify Role Trust Policy

```bash
aws iam get-role \
  --role-name DevOpsAgentCrossAccountRole \
  --query 'Role.AssumeRolePolicyDocument' \
  --profile <target-account-profile>
```

Should show:
- Principal: Your AgentSpace role ARN
- ExternalId: Your Agent Space ARN

## Updating Roles (If Needed)

If you need to update the role (e.g., add permissions):

1. Update the CloudFormation template
2. Go to StackSets → Select your StackSet
3. Click **Actions** → **Edit StackSet details**
4. Upload new template
5. Click through to deploy updates

## Cleanup (If Needed)

### Delete All Stack Instances
```bash
aws cloudformation delete-stack-instances \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --accounts <account-ids> \
  --regions us-east-1 \
  --no-retain-stacks \
  --profile zayo-ct
```

### Delete StackSet
```bash
aws cloudformation delete-stack-set \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --profile zayo-ct
```

## Best Practices

1. **Test First**: Deploy to 2-3 test accounts before all 50
2. **Use OUs**: Organize accounts in OUs for easier management
3. **Monitor Deployment**: Watch for failures and address them
4. **Document Account IDs**: Keep a list of all 50 account IDs for Terraform
5. **Version Control**: Store the CloudFormation template in Git

## Cost

- StackSets are free
- IAM roles are free
- No additional cost for this deployment

---

**Next Steps:**
1. Deploy StackSet to all 50 target accounts
2. Wait for completion (5-10 minutes)
3. Update terraform.tfvars with all 50 accounts
4. Run `terraform apply` to create associations
5. Verify with `./post-deploy.sh`
