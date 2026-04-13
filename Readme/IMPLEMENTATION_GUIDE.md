# AWS DevOps Agent Deployment - Step-by-Step Implementation Guide
## Created by murthy on 02/02/2026

## Overview

This guide provides the **exact steps** to deploy AWS DevOps Agent with 50 target accounts using CloudFormation StackSets + Terraform.

**Total Time:** ~30 minutes  
**Monitoring Account:** 414351351247 (zayo-ct)  
**Target Accounts:** 50 accounts  
**Region:** us-east-1

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS CLI configured with `zayo-ct` profile
- [ ] Terraform >= 1.0 installed
- [ ] Access to AWS Console for monitoring account
- [ ] List of all 50 target account IDs
- [ ] `OrganizationAccountAccessRole` exists in all target accounts
- [ ] Permissions to create IAM roles and DevOps Agent resources

---

## Phase 1: Deploy Monitoring Account Infrastructure (10 minutes)

### Step 1.1: Navigate to Project Directory

```bash
cd /Users/mv2s/Desktop/Zayo-work/devOps-Agent-project/aws-devops-agent-terraform
```

### Step 1.2: Review Configuration

```bash
# Review terraform.tfvars
cat terraform.tfvars

# Verify settings:
# - agent_space_name = "ZayodevopsAgentSpace"
# - create_cross_account_roles = false
# - external_accounts has only 1 account (for now)
```

### Step 1.3: Initialize Terraform

```bash
terraform init
```

**Expected Output:** Providers downloaded successfully

### Step 1.4: Plan Deployment

```bash
terraform plan
```

**Review:** Should show creation of Agent Space, IAM roles, and 1 association

### Step 1.5: Deploy

```bash
terraform apply
```

**Type:** `yes` when prompted

**Expected Time:** 2-3 minutes

### Step 1.6: Save Important Values

```bash
# Save these values - you'll need them for StackSet
terraform output -raw account_id > /tmp/monitoring_account.txt
terraform output -raw devops_agentspace_role_arn > /tmp/agentspace_role_arn.txt
terraform output -raw agent_space_arn > /tmp/agent_space_arn.txt

# Display values
echo "Monitoring Account: $(cat /tmp/monitoring_account.txt)"
echo "AgentSpace Role ARN: $(cat /tmp/agentspace_role_arn.txt)"
echo "Agent Space ARN: $(cat /tmp/agent_space_arn.txt)"
```

**✅ Phase 1 Complete:** Monitoring account infrastructure deployed

---

## Phase 2: Deploy Cross-Account Roles to 50 Accounts (10 minutes)

### Step 2.1: Prepare Account List

```bash
# Create list of your 50 target account IDs
cat > cloudformation/target-accounts.txt << 'EOF'
608649261817
123456789012
234567890123
345678901234
456789012345
# ... add all 50 accounts (one per line)
EOF
```

### Step 2.2: Open AWS Console

1. Log into AWS Console with `zayo-ct` profile
2. Ensure you're in **us-east-1** region
3. Go to **CloudFormation** service
4. Click **StackSets** in left navigation

### Step 2.3: Create StackSet

**Click:** "Create StackSet"

**Step 1 - Choose a template:**
- Select: "Template is ready"
- Select: "Upload a template file"
- Click: "Choose file"
- Select: `cloudformation/cross-account-role-stackset.yaml`
- Click: "Next"

**Step 2 - Specify StackSet details:**
- **StackSet name:** `DevOpsAgent-CrossAccountRoles`
- **Parameters:**
  - **MonitoringAccountId:** `414351351247` (from terraform output)
  - **AgentSpaceRoleArn:** Paste from `/tmp/agentspace_role_arn.txt`
  - **AgentSpaceArn:** Paste from `/tmp/agent_space_arn.txt`
- Click: "Next"

**Step 3 - Configure StackSet options:**
- **Execution configuration:** Service-managed permissions
- **Tags (optional):**
  - Key: `Project`, Value: `aws-devops-agent`
  - Key: `CreatedBy`, Value: `murthy`
- Click: "Next"

**Step 4 - Set deployment targets:**
- **Deployment targets:** 
  - Option A: "Deploy to organization" (if all 50 are in one OU)
  - Option B: "Deploy to accounts" → Paste all 50 account IDs (comma-separated)
- **Regions:** Select `us-east-1` only
- **Deployment options:**
  - Maximum concurrent accounts: `10`
  - Failure tolerance: `5`
  - Region Concurrency: Sequential
- Click: "Next"

**Step 5 - Review:**
- Review all settings
- Check: "I acknowledge that AWS CloudFormation might create IAM resources"
- Click: "Submit"

### Step 2.4: Monitor Deployment

1. StackSet status will show "RUNNING"
2. Click on StackSet name: `DevOpsAgent-CrossAccountRoles`
3. Go to "Stack instances" tab
4. Watch as accounts turn "CURRENT" (green)

**Expected Time:** 5-10 minutes for 50 accounts

**✅ Phase 2 Complete:** Cross-account roles deployed to all 50 accounts

---

## Phase 3: Create Associations for All 50 Accounts (5 minutes)

### Step 3.1: Generate Terraform Configuration

```bash
# Generate external_accounts configuration
bash cloudformation/generate-external-accounts.sh cloudformation/target-accounts.txt > /tmp/external-accounts-config.txt

# Preview the generated config
cat /tmp/external-accounts-config.txt
```

### Step 3.2: Update terraform.tfvars

```bash
# Backup current config
cp terraform.tfvars terraform.tfvars.backup

# Remove old external_accounts section
sed -i.bak '/^external_accounts = {/,/^}/d' terraform.tfvars

# Add new configuration with all 50 accounts
cat /tmp/external-accounts-config.txt >> terraform.tfvars
```

### Step 3.3: Verify Configuration

```bash
# Check that all 50 accounts are in terraform.tfvars
grep -c "account_id" terraform.tfvars
# Should show 50
```

### Step 3.4: Apply Terraform

```bash
terraform plan
# Review: Should show creation of 49 new associations (1 already exists)

terraform apply
# Type: yes
```

**Expected Time:** 2-3 minutes

**✅ Phase 3 Complete:** All 50 accounts associated with Agent Space

---

## Phase 4: Enable Operator App (2 minutes)

### Step 4.1: Run Post-Deployment Script

```bash
./post-deploy.sh
```

### Step 4.2: Enable Operator App

When prompted: "Do you want to enable the Operator App?"
- Type: `y`
- Press: Enter

**Expected Output:** "Operator App enabled successfully!"

**✅ Phase 4 Complete:** Operator App enabled

---

## Verification Steps

### Verify Agent Space

```bash
aws devopsagent list-agent-spaces \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1 \
  --profile zayo-ct
```

**Expected:** Shows `ZayodevopsAgentSpace`

### Verify Associations

```bash
AGENT_SPACE_ID=$(terraform output -raw agent_space_id)

aws devopsagent list-associations \
  --agent-space-id $AGENT_SPACE_ID \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1 \
  --profile zayo-ct
```

**Expected:** Shows 51 associations (1 primary + 50 external)

### Verify Cross-Account Role (Sample)

```bash
# Pick one target account to verify
aws iam get-role \
  --role-name DevOpsAgentCrossAccountRole \
  --profile <target-account-profile>
```

**Expected:** Role exists with proper trust policy

### Access Console

Open browser: https://console.aws.amazon.com/devopsagent/

**Expected:** See your Agent Space with all 50 accounts

---

## Troubleshooting

### Issue: StackSet deployment fails for some accounts

**Solution:**
1. Go to StackSets → Stack instances
2. Find failed instances
3. Check error message
4. Fix issue in that account
5. Click "Retry" for failed instances

### Issue: Terraform association fails

**Error:** "Role not found"

**Solution:**
```bash
# Wait 2-3 minutes for IAM propagation
sleep 180

# Retry
terraform apply
```

### Issue: Too many accounts in terraform.tfvars

**Solution:**
```bash
# Split into multiple files if needed
# Or use Terraform workspaces
```

---

## Post-Deployment

### What You Have Now

✅ **Monitoring Account (414351351247):**
- Agent Space: `ZayodevopsAgentSpace`
- IAM Roles: AgentSpace, Operator
- 51 Associations (1 primary + 50 external)
- Operator App: Enabled

✅ **50 Target Accounts:**
- Cross-Account Role: `DevOpsAgentCrossAccountRole`
- Trust Policy: Points to monitoring account
- Permissions: AIOpsAssistantPolicy + additional

### Next Steps

1. **Test Monitoring:** Check DevOps Agent console for insights
2. **Set Up Alerts:** Configure notifications
3. **Train Team:** Share console access
4. **Document:** Update runbooks

---

## Cleanup (If Needed)

### Remove Everything

```bash
# 1. Destroy Terraform resources
terraform destroy

# 2. Delete StackSet instances
aws cloudformation delete-stack-instances \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --accounts $(cat cloudformation/target-accounts.txt | tr '\n' ' ') \
  --regions us-east-1 \
  --no-retain-stacks \
  --profile zayo-ct

# 3. Delete StackSet
aws cloudformation delete-stack-set \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --profile zayo-ct
```

---

## Summary

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Deploy monitoring account | 10 min | ⬜ |
| 2 | Deploy cross-account roles (50) | 10 min | ⬜ |
| 3 | Create associations (50) | 5 min | ⬜ |
| 4 | Enable Operator App | 2 min | ⬜ |
| **Total** | **Complete deployment** | **~30 min** | ⬜ |

---

## Support

- **Step-by-Step Guide:** `IMPLEMENTATION_GUIDE.md`
- **CloudFormation Console Guide:** `cloudformation/STACKSET_DEPLOYMENT_GUIDE.md`
- **Architecture Details:** `MULTI_ACCOUNT_STRATEGY.md`
- **Project Overview:** `README.md`

---

**Created by:** murthy  
**Date:** 02/02/2026  
**Version:** 1.0  
**Status:** Production Ready

# IAM ROLES AND VISUAL FLOW
## IAM Roles Summary

### **SOURCE ACCOUNT (Monitoring Account: 414351351247)**
Where DevOps Agent Space is deployed - 2 roles created by Terraform:

#### 1. DevOpsAgentRole-AgentSpace-{suffix}
- **Purpose**: Main Agent Space role for monitoring and investigations
- **Trusted by**: aidevops.amazonaws.com service
- **Permissions**:
  - AWS Managed Policy: AIOpsAssistantPolicy
  - Support actions: CreateCase, DescribeCases
  - Extended actions: GetKnowledgeItem, ListKnowledgeItems, eks:AccessKubernetesApi, synthetics:GetCanaryRuns, route53:GetHealthCheckStatus, resource-explorer-2:Search
- **Can assume**: Cross-account roles in target accounts

#### 2. DevOpsAgentRole-WebappAdmin-{suffix}
- **Purpose**: Operator App role for web console access
- **Trusted by**: aidevops.amazonaws.com service
- **Permissions**:
  - DevOps Agent operations: GetAgentSpace, InvokeAgent, CreateBacklogTask, ListRecommendations, etc.
  - Support operations: DescribeCases, InitiateChatForCase, DescribeSupportLevel
- **Used for**: Web UI authentication (IAM or IDC)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


### **TARGET ACCOUNTS (External Accounts: 608649261817 + 49 others)**
Accounts being monitored - 1 role created by CloudFormation StackSet:

#### 1. DevOpsAgentCrossAccountRole
- **Purpose**: Allow source account's Agent Space to monitor this account
- **Trusted by**: DevOpsAgentRole-AgentSpace-{suffix} from monitoring account (414351351247)
- **External ID**: Agent Space ARN (for security)
- **Permissions**:
  - AWS Managed Policy: AIOpsAssistantPolicy
  - Support actions: CreateCase, DescribeCases
  - Extended actions: Same as Agent Space role
- **Assumed by**: Agent Space role in source account

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


## Visual Flow

SOURCE ACCOUNT (414351351247)
├── DevOpsAgentRole-AgentSpace-{suffix}
│   └── Assumes → DevOpsAgentCrossAccountRole in target accounts
│   └── Monitors resources across all 50 accounts
│
└── DevOpsAgentRole-WebappAdmin-{suffix}
    └── Used by operators accessing DevOps Agent web console

TARGET ACCOUNTS (608649261817, etc.)
└── DevOpsAgentCrossAccountRole
    └── Trusts DevOpsAgentRole-AgentSpace from 414351351247
    └── Allows monitoring of resources in this account


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


## Key Security Points

1. External ID: Target account roles require Agent Space ARN as External ID
2. Trust Relationship: Target accounts only trust the specific Agent Space role ARN
3. Least Privilege: Both roles use AWS managed AIOpsAssistantPolicy + minimal additional permissions
4. Service Principal: Source account roles trust aidevops.amazonaws.com service


DEVOPs agent to SNOW communication:
This is the key architectural piece. Let me clarify the missing link:

## The Problem:

AWS DevOps Agent (AWS-managed) cannot directly use your VPC endpoint because:
- It runs in AWS's infrastructure, not your VPC
- It has no network path to your VPC endpoints
- AWS hasn't documented any way to route DevOps Agent traffic through customer VPCs

## The Solution: You Need a Bridge

The VPC endpoint doesn't connect directly to DevOps Agent. You need middleware in your VPC:

┌──────────────────────────────────────────────────────────┐
│ AWS DevOps Agent (AWS-managed, outside your VPC)         │
│ - Detects issues, generates findings                     │
└────────────────┬─────────────────────────────────────────┘
                 │
                 │ How does it notify you?
                 │ ↓ (EventBridge, SNS, or polling)
                 │
┌────────────────▼─────────────────────────────────────────┐
│ EventBridge Rule / SNS Topic (in your account)           │
│ - Receives events from DevOps Agent                      │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ↓ (triggers)
┌────────────────▼─────────────────────────────────────────┐
│ Lambda Function (in YOUR VPC)                           │
│ - Attached to VPC subnets                               │
│ - Has access to VPC endpoints                           │
│ - Transforms DevOps Agent findings → SNOW format        │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ↓ (uses VPC endpoint)
┌────────────────▼─────────────────────────────────────────┐
│ VPC Endpoint (Interface Endpoint)                        │
│ - Private IP in your subnet                              │
│ - DNS resolves zayo.service-now.com to private IP        │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ↓ (AWS PrivateLink connection)
┌────────────────▼─────────────────────────────────────────┐
│ ServiceNow SaaS (PrivateLink enabled)                    │
└──────────────────────────────────────────────────────────┘

## Key Points:

1. DevOps Agent → EventBridge: AWS-managed, happens automatically
2. EventBridge → Lambda: Standard AWS event routing
3. Lambda → VPC Endpoint: Lambda MUST be VPC-attached
4. VPC Endpoint → ServiceNow: PrivateLink connection

## The Critical Requirement:

Lambda must be deployed IN your VPC to use the VPC endpoint. Without this, Lambda uses public internet.

## Reality Check:

Does ServiceNow actually offer PrivateLink to Zayo?

You need to verify with ServiceNow:
1. Is PrivateLink available for your subscription tier?
2. What's the VPC Endpoint Service Name?
3. What's the additional cost?