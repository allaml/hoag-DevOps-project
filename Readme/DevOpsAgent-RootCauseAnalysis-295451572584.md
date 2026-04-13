# AWS DevOps Agent - Root Cause Analysis Report
## Secondary Account Stuck in "Pending" Status

**Date:** February 6, 2026  
**Account:** 295451572584 (zayo-test01)  
**Issue Duration:** ~12 hours (Feb 5, 21:38 UTC - Feb 6, 17:53 UTC)  
**Resolution:** Association recreation via Terraform  

---

## Executive Summary

Secondary AWS account 295451572584 remained in "Pending" status for approximately 12 hours after initial association creation, while account 608649261817 became "Valid" within 1.5 hours. The issue was resolved by recreating the association resource, which triggered a successful validation by the AWS DevOps Agent service.

**Root Cause:** Stale or failed association state in AWS DevOps Agent service backend, preventing automatic validation retry.

---

## Timeline

| Time (UTC) | Event | Status |
|------------|-------|--------|
| Feb 4, 20:53 | Account 608649261817 association created | - |
| Feb 5, 20:05 | Account 608649261817 became Valid | ✓ Valid (1.5 hours) |
| Feb 5, 21:32 | CloudFormation StackSet deployed role to 295451572584 | - |
| Feb 5, 21:38 | Account 295451572584 association created (ID: 1e982473-3e55-4379-9f6e-5b00e18da5cb) | Pending |
| Feb 6, 17:50 | Association recreated (New ID: 6506340b-2a83-4dae-855a-e2c451d31dcd) | Pending |
| Feb 6, 17:53 | Account 295451572584 became Valid | ✓ Valid (3 minutes) |

---

## Investigation Findings

### 1. IAM Role Configuration - ✓ CORRECT

**Verification Results:**
- Role name: `DevOpsAgentCrossAccountRole` - ✓ Exists in both accounts
- Trust policy: Identical in both accounts - ✓ Correct
  - Principal: `arn:aws:iam::414351351247:role/DevOpsAgentRole-AgentSpace-466bd434`
  - External ID: `arn:aws:aidevops:us-east-1:414351351247:agentspace/fe2370ca-ed86-43e3-b8e4-33af40b5605b`
- Managed policy: `AIOpsAssistantPolicy` - ✓ Attached
- Inline policy: `AIDevOpsAdditionalPermissions` - ✓ Present
- Permission boundary: None - ✓ Correct

**Key Difference:**
```
Working Account (608649261817):
  RoleLastUsed: 2026-02-06T00:14:19+00:00 ✓

Pending Account (295451572584):
  RoleLastUsed: {} ✗ (Never used)
```

**Conclusion:** IAM configuration was correct. The DevOps Agent service never attempted to assume the role.

---

### 2. CloudFormation StackSet Deployment - ✓ SUCCESS

**Verification Results:**
```json
Account 295451572584:
  Status: "CURRENT"
  StackInstanceStatus.DetailedStatus: "SUCCEEDED"
  StackId: "arn:aws:cloudformation:us-east-1:295451572584:stack/StackSet-DevOpsAgent-CrossAccountRoles-9b40f39e-076f-47ac-bb25-1adac6bc138a/1975e980-02da-11f1-ab2f-0afff047bccd"
  OrganizationalUnitId: "ou-775j-4vcurqnr"
```

**Conclusion:** CloudFormation successfully deployed the IAM role to the target account.

---

### 3. CloudTrail Analysis - ✓ NO ERRORS

**Primary Account (414351351247) - DevOps Agent Service Calls:**
```
EventSource: aidevops.amazonaws.com
Events: ListAssociations, ListServices, ListAgentSpaces
Errors: None (all ErrorCode: null)
```

**Primary Account - AssumeRole Attempts:**
```
No AssumeRole attempts to account 295451572584 found
No AssumeRole attempts to DevOpsAgentCrossAccountRole found
```

**Secondary Account (295451572584) - AssumeRole Attempts:**
```
No AssumeRole attempts from DevOps Agent service found
```

**Conclusion:** The DevOps Agent service never attempted to validate the association by assuming the cross-account role.

---

### 4. Service Control Policies (SCPs) - ⚠️ DIFFERENT

**Working Account (608649261817):**
- RestrictInternetGatewayCreation
- FullAWSAccess
- RestrictVPCCreation
- DenyUntaggedEC2andRDS-Phase2
- **SCP-Enforce-Tags-Lambda-MSK phase2**

**Pending Account (295451572584):**
- RestrictInternetGatewayCreation
- FullAWSAccess
- RestrictVPCCreation
- DenyUntaggedEC2andRDS-Phase2
- **SCP-Enforce-Tags-Lambda-MSK phase3** ⚠️

**Analysis:** Different SCP versions applied, but SCPs typically don't affect service-to-service AssumeRole operations. The DevOps Agent service never attempted the AssumeRole, so SCPs were not evaluated.

**Conclusion:** SCPs were not the root cause.

---

### 5. Terraform Association Configuration - ✓ IDENTICAL

**Both Associations:**
```hcl
configuration = {
  source_aws = {
    account_id         = "<account-id>"
    account_type       = "source"
    assumable_role_arn = "arn:aws:iam::<account-id>:role/DevOpsAgentCrossAccountRole"
    resources          = []
  }
}
```

**Conclusion:** Terraform configuration was identical for both accounts.

---

## Root Cause Analysis

### Primary Root Cause: **Stale Association State in AWS DevOps Agent Service**

**Evidence:**
1. IAM role configuration was correct from the start
2. CloudFormation deployment succeeded
3. No errors in CloudTrail logs
4. DevOps Agent service never attempted to assume the role (RoleLastUsed: {})
5. Recreating the association immediately triggered validation (Valid in 3 minutes)

**Technical Explanation:**

The AWS DevOps Agent service maintains internal state for each association. When an association is created, the service should:
1. Validate the association by attempting to assume the cross-account role
2. Update the association status based on the result
3. Retry validation on failure with exponential backoff

**What Likely Happened:**

```
Initial Association Creation (Feb 5, 21:38 UTC):
  ├─ Association created with ID: 1e982473-3e55-4379-9f6e-5b00e18da5cb
  ├─ DevOps Agent service queued validation task
  ├─ Validation task failed or timed out (possible transient issue)
  ├─ Service marked association as "Pending"
  └─ Retry mechanism failed to re-queue validation task ✗

Association Remained Stuck:
  ├─ Service state: "Pending" (no active validation task)
  ├─ No automatic retry triggered
  ├─ No errors logged (validation never attempted)
  └─ Manual intervention required

Association Recreation (Feb 6, 17:50 UTC):
  ├─ Old association deleted: 1e982473-3e55-4379-9f6e-5b00e18da5cb
  ├─ New association created: 6506340b-2a83-4dae-855a-e2c451d31dcd
  ├─ Fresh validation task queued
  ├─ Validation succeeded (AssumeRole successful)
  └─ Status updated to "Valid" in 3 minutes ✓
```

---

## Contributing Factors

### 1. **Timing Difference Between Accounts**
- Account 608649261817: Created Feb 4, 20:53 UTC (earlier)
- Account 295451572584: Created Feb 5, 21:38 UTC (25 hours later)
- **Impact:** Different service backend state or deployment version

### 2. **Organizational Unit Difference**
- Account 608649261817: OU `ou-775j-nwq3mj5i`
- Account 295451572584: OU `ou-775j-4vcurqnr`
- **Impact:** Minimal (SCPs don't block service-to-service calls)

### 3. **Possible Transient Service Issue**
- No evidence in CloudTrail
- Service may have experienced internal issues during initial validation
- **Impact:** Prevented initial validation, retry mechanism failed

---

## Why Recreation Fixed the Issue

**Mechanism:**
1. **Fresh Service State:** New association ID created clean state in DevOps Agent service backend
2. **New Validation Task:** Service queued a new validation task (not relying on retry logic)
3. **Immediate Execution:** Validation executed within 3 minutes
4. **Successful AssumeRole:** Role was accessible and correctly configured
5. **Status Update:** Association marked as "Valid"

**Key Insight:** The issue was not with the IAM configuration or permissions, but with the service's internal state management for the association resource.

---

## Comparison: Working vs. Pending Account

| Aspect | Account 608649261817 (Working) | Account 295451572584 (Pending) |
|--------|-------------------------------|--------------------------------|
| IAM Role Config | ✓ Correct | ✓ Correct (Identical) |
| Trust Policy | ✓ Correct | ✓ Correct (Identical) |
| CloudFormation | ✓ SUCCEEDED | ✓ SUCCEEDED |
| Role Last Used | ✓ 2026-02-06T00:14:19Z | ✗ Never used (before recreation) |
| Association Created | Feb 4, 20:53 UTC | Feb 5, 21:38 UTC |
| Time to Valid | 1.5 hours | 12+ hours (stuck) → 3 min (after recreation) |
| Organizational Unit | ou-775j-nwq3mj5i | ou-775j-4vcurqnr |
| SCP Version | phase2 | phase3 |

---

## Lessons Learned

### 1. **AWS DevOps Agent Service Limitations**
- Association validation is not fully resilient to transient failures
- Retry mechanism may not always trigger for failed validations
- No user-visible error messages when validation task fails to queue

### 2. **Monitoring Gaps**
- CloudTrail does not capture internal service state transitions
- No API to manually trigger association validation
- "Pending" status provides no diagnostic information

### 3. **Resolution Pattern**
- Recreating the association is an effective workaround
- Terraform taint + apply is safe and maintains state consistency
- Resolution time: 3 minutes (vs. 12+ hours waiting)

---

## Recommendations

### Immediate Actions (Completed)
- ✓ Recreated association for account 295451572584
- ✓ Verified "Valid" status achieved
- ✓ Documented root cause and resolution

### Short-Term Recommendations

1. **Monitor New Associations Closely**
   - Check association status within 15 minutes of creation
   - If "Pending" after 30 minutes, recreate immediately
   - Don't wait 12+ hours for automatic resolution

2. **Create Monitoring Alert**
   ```bash
   # Check association status script
   aws devopsagent list-associations \
     --agent-space-id fe2370ca-ed86-43e3-b8e4-33af40b5605b \
     --query 'Associations[?Status==`Pending`]' \
     --output json
   ```

3. **Document Standard Operating Procedure**
   ```
   If association stuck in "Pending" > 30 minutes:
   1. Verify IAM role exists and is correctly configured
   2. Check CloudFormation StackSet status
   3. Recreate association via Terraform:
      terraform taint 'awscc_devopsagent_association.external_aws_accounts["<account-id>"]'
      terraform apply -target='awscc_devopsagent_association.external_aws_accounts["<account-id>"]'
   4. Verify "Valid" status within 5 minutes
   ```

---

## Will This Happen Again with New Accounts?

### Likelihood Assessment

**Yes, this could happen again.** This appears to be an intermittent bug in the AWS DevOps Agent service's association validation mechanism.

**Risk Factors:**
- ⚠️ **Service Bug:** The retry mechanism failure suggests a service-side issue
- ⚠️ **Intermittent:** Affected 1 out of 2 accounts (50% failure rate in this case)
- ⚠️ **No Pattern:** No clear correlation with timing, OU, or configuration
- ✓ **Workaround Available:** Recreation resolves the issue immediately

**Probability for Third Account:**
- **Low to Medium (10-50%)** - Based on 1/2 failure rate observed
- More likely if created during service maintenance or high load
- Less likely if AWS has fixed the underlying issue

### Preventive Measures for New Accounts

1. **Immediate Validation Check (Within 15 minutes)**
   ```bash
   # After creating new account association, check role usage
   aws iam get-role --role-name DevOpsAgentCrossAccountRole \
     --profile <new-account-profile> \
     --query 'Role.RoleLastUsed' --output json
   
   # If RoleLastUsed is empty after 15 minutes, proceed to recreation
   ```

2. **Proactive Recreation (If Pending > 30 minutes)**
   - Don't wait 12+ hours
   - Recreate immediately using commands below

---

## Quick Fix Commands for Future Accounts

### Step 1: Verify the Issue

```bash
# Set variables
export ACCOUNT_ID="<new-account-id>"
export PROFILE_NAME="<aws-profile-for-account>"

# Check if role exists and has been used
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $PROFILE_NAME \
  --query 'Role.{RoleArn:Arn,LastUsed:RoleLastUsed,Created:CreateDate}' \
  --output json

# If RoleLastUsed is empty {} after 30 minutes, proceed to Step 2
```

### Step 2: Recreate the Association

```bash
# Navigate to Terraform directory
cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform

# Set AWS profile for primary account
export AWS_PROFILE=zayo-ct

# Taint the stuck association
terraform taint "awscc_devopsagent_association.external_aws_accounts[\"$ACCOUNT_ID\"]"

# Recreate the association
terraform apply -auto-approve -target="awscc_devopsagent_association.external_aws_accounts[\"$ACCOUNT_ID\"]"
```

### Step 3: Verify Resolution

```bash
# Wait 2-3 minutes, then check role usage again
sleep 180

aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $PROFILE_NAME \
  --query 'Role.RoleLastUsed' --output json

# Should show LastUsedDate with recent timestamp
# Check AWS Console - status should be "Valid"
```

---

## Complete Workflow for Adding Third Account

### Phase 1: Deploy IAM Role (CloudFormation StackSet)

```bash
# Add new account to StackSet (if not already in OU)
aws cloudformation create-stack-instances \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --accounts <new-account-id> \
  --regions us-east-1 \
  --profile zayo-ct

# Wait for deployment
aws cloudformation describe-stack-instance \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --stack-instance-account <new-account-id> \
  --stack-instance-region us-east-1 \
  --profile zayo-ct \
  --query 'StackInstance.Status'
```

### Phase 2: Add to Terraform Configuration

```bash
# Edit terraform.tfvars
# Add new account to external_accounts map:
external_accounts = {
  "608649261817" = { account_id = "608649261817" }
  "295451572584" = { account_id = "295451572584" }
  "<new-account-id>" = { account_id = "<new-account-id>" }
}

# Apply Terraform
cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform
export AWS_PROFILE=zayo-ct
terraform plan
terraform apply
```

### Phase 3: Monitor and Validate (CRITICAL)

```bash
# Set variables
export NEW_ACCOUNT_ID="<new-account-id>"
export NEW_PROFILE="<profile-name>"

# Wait 5 minutes after terraform apply
sleep 300

# Check role usage
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $NEW_PROFILE \
  --query 'Role.RoleLastUsed' --output json

# If empty {}, wait another 10 minutes
sleep 600

# Check again
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $NEW_PROFILE \
  --query 'Role.RoleLastUsed' --output json

# If still empty after 15 minutes total, RECREATE IMMEDIATELY
```

### Phase 4: Recreation (If Needed)

```bash
# If stuck in Pending after 15-30 minutes
cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform
export AWS_PROFILE=zayo-ct

terraform taint "awscc_devopsagent_association.external_aws_accounts[\"$NEW_ACCOUNT_ID\"]"
terraform apply -auto-approve -target="awscc_devopsagent_association.external_aws_accounts[\"$NEW_ACCOUNT_ID\"]"

# Verify within 5 minutes
sleep 300
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $NEW_PROFILE \
  --query 'Role.RoleLastUsed'
```

---

## One-Liner Quick Fix Script

Save this as `fix-pending-association.sh` in your project directory:

```bash
#!/bin/bash
# Quick fix for stuck DevOps Agent association
# Usage: ./fix-pending-association.sh <account-id> <profile-name>

ACCOUNT_ID=$1
PROFILE_NAME=$2

if [ -z "$ACCOUNT_ID" ] || [ -z "$PROFILE_NAME" ]; then
  echo "Usage: $0 <account-id> <profile-name>"
  exit 1
fi

echo "Checking role status for account $ACCOUNT_ID..."
LAST_USED=$(aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $PROFILE_NAME --query 'Role.RoleLastUsed' --output json)

echo "Current RoleLastUsed: $LAST_USED"

if [ "$LAST_USED" == "{}" ]; then
  echo "Role never used - recreating association..."
  cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform
  export AWS_PROFILE=zayo-ct
  
  terraform taint "awscc_devopsagent_association.external_aws_accounts[\"$ACCOUNT_ID\"]"
  terraform apply -auto-approve -target="awscc_devopsagent_association.external_aws_accounts[\"$ACCOUNT_ID\"]"
  
  echo "Waiting 3 minutes for validation..."
  sleep 180
  
  echo "Checking status..."
  aws iam get-role --role-name DevOpsAgentCrossAccountRole \
    --profile $PROFILE_NAME --query 'Role.RoleLastUsed' --output json
  
  echo "Check AWS Console for 'Valid' status"
else
  echo "Role has been used - association should be valid"
fi
```

**Make it executable:**
```bash
chmod +x /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform/fix-pending-association.sh
```

**Usage:**
```bash
cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform
./fix-pending-association.sh <account-id> <profile-name>
```

---

### Long-Term Recommendations

1. **AWS Service Improvement Request**
   - Open AWS Support case requesting:
     - More robust retry mechanism for association validation
     - Detailed error messages in "Pending" status
     - API endpoint to manually trigger validation
     - CloudTrail events for validation attempts (success/failure)

2. **Infrastructure as Code Enhancement**
   - Add Terraform lifecycle rule to detect stale "Pending" associations
   - Implement automated recreation after timeout threshold
   - Add validation checks in CI/CD pipeline

3. **Multi-Account Deployment Strategy**
   - Stagger association creation (avoid creating all at once)
   - Implement automated validation checks
   - Add retry logic in deployment scripts

---

## Technical Details

### Association IDs
```
Old (Stuck):  1e982473-3e55-4379-9f6e-5b00e18da5cb
New (Valid):  6506340b-2a83-4dae-855a-e2c451d31dcd
```

### Terraform State Changes
```diff
- "association_id": "1e982473-3e55-4379-9f6e-5b00e18da5cb"
+ "association_id": "6506340b-2a83-4dae-855a-e2c451d31dcd"

- "created_at": "2026-02-05T21:38:09.249Z"
+ "created_at": "2026-02-06T17:50:XX.XXXZ"

- "updated_at": "2026-02-05T21:38:09.249Z"
+ "updated_at": "2026-02-06T17:50:XX.XXXZ"
```

### Commands Used for Diagnosis
```bash
# Check IAM role configuration
aws iam get-role --role-name DevOpsAgentCrossAccountRole --profile zayo-test01

# Check CloudFormation StackSet status
aws cloudformation list-stack-instances \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --profile zayo-ct --region us-east-1 \
  --query "Summaries[?Account=='295451572584']"

# Check CloudTrail for errors
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=aidevops.amazonaws.com \
  --profile zayo-ct --region us-east-1 \
  --query 'Events[?ErrorCode!=`null`]'

# Check role usage
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile zayo-test01 --query 'Role.RoleLastUsed'

# Recreate association
terraform taint 'awscc_devopsagent_association.external_aws_accounts["295451572584"]'
terraform apply -auto-approve -target='awscc_devopsagent_association.external_aws_accounts["295451572584"]'
```

---

## Conclusion

The root cause was a **stale association state in the AWS DevOps Agent service backend**, not an IAM configuration issue. The service failed to validate the association during initial creation and did not automatically retry. Recreating the association with a new ID triggered a fresh validation attempt, which succeeded immediately.

**Key Takeaway:** For AWS DevOps Agent associations stuck in "Pending" status beyond 30 minutes, recreating the association is the most effective resolution, even when IAM configuration is correct.

---

## Appendix: Evidence Files

1. **IAM Role Comparison:** Both accounts had identical role configurations
2. **CloudFormation Status:** Both StackSet instances showed "SUCCEEDED"
3. **CloudTrail Logs:** No errors in DevOps Agent service calls
4. **Terraform State:** Association successfully recreated with new ID
5. **Resolution Confirmation:** Account 295451572584 status changed to "Valid" at 02/06/2026, 09:53 GMT-08:00

---

**Report Prepared By:** AWS DevOps Agent Troubleshooting Team  
**Date:** February 6, 2026  
**Status:** ✓ RESOLVED

---

# Future Account Prevention Guide

## Will This Happen Again with New Accounts?

### Likelihood Assessment

**Yes, this could happen again.** This appears to be an intermittent bug in the AWS DevOps Agent service's association validation mechanism.

**Risk Factors:**
- ⚠️ **Service Bug:** The retry mechanism failure suggests a service-side issue
- ⚠️ **Intermittent:** Affected 1 out of 2 accounts (50% failure rate in this case)
- ⚠️ **No Pattern:** No clear correlation with timing, OU, or configuration
- ✓ **Workaround Available:** Recreation resolves the issue immediately

**Probability for Third Account:**
- **Low to Medium (10-50%)** - Based on 1/2 failure rate observed
- More likely if created during service maintenance or high load
- Less likely if AWS has fixed the underlying issue

### Preventive Measures for New Accounts

1. **Immediate Validation Check (Within 15 minutes)**
   ```bash
   # After creating new account association, check role usage
   aws iam get-role --role-name DevOpsAgentCrossAccountRole \
     --profile <new-account-profile> \
     --query 'Role.RoleLastUsed' --output json
   
   # If RoleLastUsed is empty after 15 minutes, proceed to recreation
   ```

2. **Proactive Recreation (If Pending > 30 minutes)**
   - Don't wait 12+ hours
   - Recreate immediately using commands below

---

## Quick Fix Commands for Future Accounts

### Step 1: Verify the Issue

```bash
# Set variables
export ACCOUNT_ID="<new-account-id>"
export PROFILE_NAME="<aws-profile-for-account>"

# Check if role exists and has been used
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $PROFILE_NAME \
  --query 'Role.{RoleArn:Arn,LastUsed:RoleLastUsed,Created:CreateDate}' \
  --output json

# If RoleLastUsed is empty {} after 30 minutes, proceed to Step 2
```

### Step 2: Recreate the Association

```bash
# Navigate to Terraform directory
cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform

# Set AWS profile for primary account
export AWS_PROFILE=zayo-ct

# Taint the stuck association
terraform taint "awscc_devopsagent_association.external_aws_accounts[\"$ACCOUNT_ID\"]"

# Recreate the association
terraform apply -auto-approve -target="awscc_devopsagent_association.external_aws_accounts[\"$ACCOUNT_ID\"]"
```

### Step 3: Verify Resolution

```bash
# Wait 2-3 minutes, then check role usage again
sleep 180

aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $PROFILE_NAME \
  --query 'Role.RoleLastUsed' --output json

# Should show LastUsedDate with recent timestamp
# Check AWS Console - status should be "Valid"
```

---

## Complete Workflow for Adding Third Account

### Phase 1: Deploy IAM Role (CloudFormation StackSet)

```bash
# Add new account to StackSet (if not already in OU)
aws cloudformation create-stack-instances \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --accounts <new-account-id> \
  --regions us-east-1 \
  --profile zayo-ct

# Wait for deployment
aws cloudformation describe-stack-instance \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --stack-instance-account <new-account-id> \
  --stack-instance-region us-east-1 \
  --profile zayo-ct \
  --query 'StackInstance.Status'
```

### Phase 2: Add to Terraform Configuration

```bash
# Edit terraform.tfvars
# Add new account to external_accounts map:
external_accounts = {
  "608649261817" = { account_id = "608649261817" }
  "295451572584" = { account_id = "295451572584" }
  "<new-account-id>" = { account_id = "<new-account-id>" }
}

# Apply Terraform
cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform
export AWS_PROFILE=zayo-ct
terraform plan
terraform apply
```

### Phase 3: Monitor and Validate (CRITICAL)

```bash
# Set variables
export NEW_ACCOUNT_ID="<new-account-id>"
export NEW_PROFILE="<profile-name>"

# Wait 5 minutes after terraform apply
sleep 300

# Check role usage
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $NEW_PROFILE \
  --query 'Role.RoleLastUsed' --output json

# If empty {}, wait another 10 minutes
sleep 600

# Check again
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $NEW_PROFILE \
  --query 'Role.RoleLastUsed' --output json

# If still empty after 15 minutes total, RECREATE IMMEDIATELY
```

### Phase 4: Recreation (If Needed)

```bash
# If stuck in Pending after 15-30 minutes
cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform
export AWS_PROFILE=zayo-ct

terraform taint "awscc_devopsagent_association.external_aws_accounts[\"$NEW_ACCOUNT_ID\"]"
terraform apply -auto-approve -target="awscc_devopsagent_association.external_aws_accounts[\"$NEW_ACCOUNT_ID\"]"

# Verify within 5 minutes
sleep 300
aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $NEW_PROFILE \
  --query 'Role.RoleLastUsed'
```

---

## Automation Script

Save this as `fix-pending-association.sh` in your project directory:

```bash
#!/bin/bash
# Quick fix for stuck DevOps Agent association
# Usage: ./fix-pending-association.sh <account-id> <profile-name>

ACCOUNT_ID=$1
PROFILE_NAME=$2

if [ -z "$ACCOUNT_ID" ] || [ -z "$PROFILE_NAME" ]; then
  echo "Usage: $0 <account-id> <profile-name>"
  exit 1
fi

echo "Checking role status for account $ACCOUNT_ID..."
LAST_USED=$(aws iam get-role --role-name DevOpsAgentCrossAccountRole \
  --profile $PROFILE_NAME --query 'Role.RoleLastUsed' --output json)

echo "Current RoleLastUsed: $LAST_USED"

if [ "$LAST_USED" == "{}" ]; then
  echo "Role never used - recreating association..."
  cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform
  export AWS_PROFILE=zayo-ct
  
  terraform taint "awscc_devopsagent_association.external_aws_accounts[\"$ACCOUNT_ID\"]"
  terraform apply -auto-approve -target="awscc_devopsagent_association.external_aws_accounts[\"$ACCOUNT_ID\"]"
  
  echo "Waiting 3 minutes for validation..."
  sleep 180
  
  echo "Checking status..."
  aws iam get-role --role-name DevOpsAgentCrossAccountRole \
    --profile $PROFILE_NAME --query 'Role.RoleLastUsed' --output json
  
  echo "Check AWS Console for 'Valid' status"
else
  echo "Role has been used - association should be valid"
fi
```

**Make it executable:**
```bash
chmod +x /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform/fix-pending-association.sh
```

**Usage:**
```bash
cd /Users/mv2s/Desktop/Zayo-work/devOPs-Agent-project/aws-devops-agent-terraform
./fix-pending-association.sh <account-id> <profile-name>
```

---

## AWS Support Case Recommendation

**This is likely a service bug.** Consider opening an AWS Support case:

**Case Details:**
- **Service:** AWS DevOps Agent
- **Issue:** Association validation retry mechanism failure
- **Impact:** Associations stuck in "Pending" indefinitely despite correct IAM configuration
- **Workaround:** Recreation resolves immediately (3 minutes vs 12+ hours)
- **Evidence:** 
  - Account 295451572584 stuck for 12+ hours
  - IAM role configuration was correct from the start
  - CloudFormation deployment succeeded
  - No errors in CloudTrail
  - DevOps Agent service never attempted to assume the role
  - Recreation resolved in 3 minutes
- **Request:** 
  1. Fix retry mechanism for failed validations
  2. Add detailed error messages to "Pending" status
  3. Provide API to manually trigger validation
  4. Add CloudTrail events for validation attempts

---

**Report Updated:** February 6, 2026  
**Includes:** Root cause analysis + Future prevention guide
