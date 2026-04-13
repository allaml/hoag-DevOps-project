# CloudFormation StackSet Approach for 50+ Target Accounts
## Created by murthy on 02/02/2026

## Why Use CloudFormation StackSets?

For **50 target accounts**, CloudFormation StackSets is the **best approach** because:

✅ **Scalable**: Deploy to unlimited accounts simultaneously  
✅ **Managed**: AWS handles the deployment orchestration  
✅ **Reliable**: Built-in retry and failure handling  
✅ **Auditable**: Full deployment history and status tracking  
✅ **Maintainable**: Easy to update roles across all accounts  
✅ **No Terraform Complexity**: Avoids 50 provider aliases  

## Architecture

```
Monitoring Account (414351351247 - zayo-ct)
├── Terraform manages:
│   ├── Agent Space
│   ├── IAM Roles (AgentSpace, Operator)
│   └── Associations (50 external accounts)
│
└── CloudFormation StackSet manages:
    └── Cross-account roles in 50 target accounts
        ├── Account 608649261817 → DevOpsAgentCrossAccountRole
        ├── Account 123456789012 → DevOpsAgentCrossAccountRole
        └── ... (48 more accounts)
```

## Deployment Workflow

### Phase 1: Deploy Monitoring Infrastructure (Terraform)
```bash
# 1. Configure terraform.tfvars (WITHOUT external_accounts)
cd aws-devops-agent-terraform
terraform init
terraform apply

# 2. Save outputs for StackSet parameters
terraform output -raw account_id
terraform output -raw devops_agentspace_role_arn
terraform output -raw agent_space_arn
```

### Phase 2: Deploy Cross-Account Roles (CloudFormation StackSet)
```bash
# Via AWS Console (recommended) - see STACKSET_DEPLOYMENT_GUIDE.md
# Or via CLI:
aws cloudformation create-stack-set \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --template-body file://cloudformation/cross-account-role-stackset.yaml \
  --parameters \
    ParameterKey=MonitoringAccountId,ParameterValue=414351351247 \
    ParameterKey=AgentSpaceRoleArn,ParameterValue=<ROLE_ARN> \
    ParameterKey=AgentSpaceArn,ParameterValue=<AGENT_SPACE_ARN> \
  --capabilities CAPABILITY_NAMED_IAM \
  --permission-model SERVICE_MANAGED \
  --auto-deployment Enabled=true \
  --region us-east-1

# Deploy to all target accounts
aws cloudformation create-stack-instances \
  --stack-set-name DevOpsAgent-CrossAccountRoles \
  --accounts 608649261817 123456789012 ... \
  --regions us-east-1
```

### Phase 3: Create Associations (Terraform)
```bash
# 1. Generate external_accounts configuration
echo "608649261817" > cloudformation/target-accounts.txt
echo "123456789012" >> cloudformation/target-accounts.txt
# ... add all 50 accounts

bash cloudformation/generate-external-accounts.sh > external-accounts-config.txt

# 2. Add to terraform.tfvars
cat external-accounts-config.txt >> terraform.tfvars

# 3. Apply to create associations
terraform apply
```

### Phase 4: Enable Operator App
```bash
./post-deploy.sh
```

## Files Included

```
cloudformation/
├── cross-account-role-stackset.yaml       # CloudFormation template
├── STACKSET_DEPLOYMENT_GUIDE.md           # Detailed console deployment guide
├── generate-external-accounts.sh          # Helper script for terraform.tfvars
├── target-accounts.txt.example            # Example account list
└── README.md                              # This file
```

## Quick Start (Console Deployment)

1. **Deploy Terraform** (monitoring account only)
   ```bash
   terraform apply
   ```

2. **Get Parameters**
   ```bash
   terraform output
   ```

3. **Deploy StackSet** (AWS Console)
   - Go to CloudFormation → StackSets → Create StackSet
   - Upload `cross-account-role-stackset.yaml`
   - Enter parameters from terraform output
   - Deploy to all 50 target accounts
   - Wait 5-10 minutes

4. **Update Terraform**
   ```bash
   # Add external_accounts to terraform.tfvars
   terraform apply
   ```

5. **Verify**
   ```bash
   ./post-deploy.sh
   ```

## Comparison: StackSet vs Terraform Provider Aliases

| Aspect | CloudFormation StackSet | Terraform Provider Aliases |
|--------|------------------------|---------------------------|
| **Scalability** | ✅ Unlimited accounts | ❌ Complex for 50+ accounts |
| **Deployment Speed** | ✅ Parallel (10 at a time) | ❌ Sequential |
| **Maintenance** | ✅ Single template | ❌ 50 provider blocks |
| **Error Handling** | ✅ Built-in retry | ❌ Manual retry |
| **AWS Best Practice** | ✅ Yes | ⚠️ Not for this scale |
| **Complexity** | ✅ Simple | ❌ Very complex |

## Recommendation

**For 50 target accounts: Use CloudFormation StackSets**

The automated Terraform approach (`create_cross_account_roles = true`) is only suitable for:
- 1-3 target accounts
- Testing/demo environments
- When you want everything in Terraform

For production with 50 accounts, StackSets is the industry-standard approach.

## Support

- **StackSet Issues**: See `STACKSET_DEPLOYMENT_GUIDE.md`
- **Terraform Issues**: See main `README.md`
- **General Questions**: See `DEPLOYMENT_NOTES.md`

---

**Created by:** murthy  
**Date:** 02/02/2026  
**Monitoring Account:** 414351351247 (zayo-ct)  
**Target Accounts:** 50
