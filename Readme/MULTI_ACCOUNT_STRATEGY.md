# Multi-Account Deployment Strategy
## Created by murthy on 02/02/2026

## Your Scenario: 50 Target Accounts

For **50 target accounts**, the recommended approach is:

## ✅ CloudFormation StackSets (Recommended)

### Why This is Best for 50 Accounts

| Factor | CloudFormation StackSets | Terraform Automated | Manual |
|--------|-------------------------|---------------------|--------|
| **Scalability** | ✅ Unlimited | ❌ Max 3-5 practical | ⚠️ Time-consuming |
| **Deployment Time** | ✅ 5-10 min (parallel) | ❌ 50+ min (sequential) | ❌ Hours |
| **Maintenance** | ✅ Single template | ❌ 50 provider aliases | ❌ 50 manual updates |
| **Error Recovery** | ✅ Built-in retry | ❌ Manual | ❌ Manual |
| **AWS Best Practice** | ✅ Yes | ❌ No | ⚠️ Acceptable |
| **Complexity** | ✅ Low | ❌ Very High | ⚠️ Medium |
| **Auditability** | ✅ Full history | ⚠️ Terraform state | ❌ Manual tracking |

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Monitoring Account (414351351247 - zayo-ct)                 │
│                                                              │
│  ┌──────────────────┐         ┌─────────────────────────┐  │
│  │   Terraform      │         │  CloudFormation         │  │
│  │   Manages:       │         │  StackSet Manages:      │  │
│  │                  │         │                         │  │
│  │  • Agent Space   │         │  • Cross-account roles  │  │
│  │  • IAM Roles     │         │    in 50 target accounts│  │
│  │  • Associations  │         │                         │  │
│  └──────────────────┘         └─────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Deploys to
                              ▼
        ┌─────────────────────────────────────────┐
        │  50 Target Accounts                     │
        │                                          │
        │  Each gets:                              │
        │  • DevOpsAgentCrossAccountRole          │
        │  • Trust policy → Monitoring account    │
        │  • AIOpsAssistantPolicy attached        │
        └─────────────────────────────────────────┘
```

## Step-by-Step Deployment

### Phase 1: Monitoring Account Setup (5 minutes)

```bash
cd aws-devops-agent-terraform

# Configure terraform.tfvars (WITHOUT external_accounts yet)
# Set: create_cross_account_roles = false

terraform init
terraform apply

# Save these values for StackSet
terraform output -raw account_id              # 414351351247
terraform output -raw devops_agentspace_role_arn
terraform output -raw agent_space_arn
```

### Phase 2: Deploy Cross-Account Roles (10 minutes)

**Via AWS Console (Easiest):**

1. Go to CloudFormation → StackSets → Create StackSet
2. Upload: `cloudformation/cross-account-role-stackset.yaml`
3. Enter parameters from terraform outputs
4. Deploy to all 50 accounts (or specific OU)
5. Wait for completion

**Detailed guide:** `cloudformation/STACKSET_DEPLOYMENT_GUIDE.md`

### Phase 3: Create Associations (5 minutes)

```bash
# 1. Create list of account IDs
cat > cloudformation/target-accounts.txt << EOF
608649261817
123456789012
234567890123
... (all 50 accounts)
EOF

# 2. Generate terraform configuration
bash cloudformation/generate-external-accounts.sh > external-accounts-config.txt

# 3. Add to terraform.tfvars
cat external-accounts-config.txt >> terraform.tfvars

# 4. Apply
terraform apply
```

### Phase 4: Enable Operator App (2 minutes)

```bash
./post-deploy.sh
```

**Total Time: ~20-25 minutes for 50 accounts**

## What Gets Created

### In Monitoring Account (414351351247)
- ✅ Agent Space: `ZayodevopsAgentSpace`
- ✅ IAM Role: `DevOpsAgentRole-AgentSpace-<random>`
- ✅ IAM Role: `DevOpsAgentRole-WebappAdmin-<random>`
- ✅ 1 Primary account association
- ✅ 50 External account associations

### In Each Target Account (50 accounts)
- ✅ IAM Role: `DevOpsAgentCrossAccountRole`
  - Trust: Monitoring account's AgentSpace role
  - ExternalId: Agent Space ARN
  - Policy: AIOpsAssistantPolicy + additional permissions

## Files You Need

```
aws-devops-agent-terraform/
├── terraform.tfvars                          # Your configuration
├── cloudformation/
│   ├── cross-account-role-stackset.yaml     # StackSet template
│   ├── STACKSET_DEPLOYMENT_GUIDE.md         # Console deployment guide
│   ├── generate-external-accounts.sh        # Helper script
│   ├── target-accounts.txt                  # Your 50 account IDs
│   └── README.md                            # CloudFormation overview
└── README.md                                # Main documentation
```

## Verification Checklist

- [ ] StackSet deployed successfully to all 50 accounts
- [ ] All stack instances show "CURRENT" status
- [ ] Terraform applied without errors
- [ ] 50 associations created in Agent Space
- [ ] Operator App enabled (optional)
- [ ] Can access DevOps Agent console

## Troubleshooting

### StackSet Deployment Issues

**Problem:** Some accounts fail to deploy
- **Check:** StackSet execution role exists in target accounts
- **Fix:** Retry failed instances from console

**Problem:** "Role already exists"
- **Check:** Previous deployment or manual creation
- **Fix:** Delete existing roles or use update operation

### Terraform Association Issues

**Problem:** "Role not found" error
- **Check:** StackSet deployment completed
- **Wait:** 2-3 minutes for IAM propagation
- **Retry:** `terraform apply`

**Problem:** Too many accounts to manage
- **Solution:** Use Terraform workspaces or separate state files per region/OU

## Maintenance

### Adding New Target Accounts

1. Deploy StackSet to new accounts:
   ```bash
   aws cloudformation create-stack-instances \
     --stack-set-name DevOpsAgent-CrossAccountRoles \
     --accounts <new-account-ids> \
     --regions us-east-1
   ```

2. Add to terraform.tfvars and apply:
   ```bash
   terraform apply
   ```

### Updating Cross-Account Roles

1. Update CloudFormation template
2. Update StackSet from console
3. Changes propagate to all 50 accounts automatically

### Removing Target Accounts

1. Remove from terraform.tfvars
2. Run `terraform apply` (removes associations)
3. Delete stack instances from StackSet

## Cost Estimate

- **CloudFormation StackSets:** Free
- **IAM Roles:** Free
- **DevOps Agent:** Preview (pricing TBD)
- **Total Additional Cost:** $0

## Support & Documentation

- **StackSet Guide:** `cloudformation/STACKSET_DEPLOYMENT_GUIDE.md`
- **Terraform Guide:** `README.md`
- **Deployment Notes:** `DEPLOYMENT_NOTES.md`
- **Quick Reference:** `QUICK_REFERENCE.md`

---

## My Recommendation for Your 50 Accounts

**Use CloudFormation StackSets** because:

1. ✅ **Proven at scale** - AWS uses this for multi-account deployments
2. ✅ **Fast** - 10 accounts in parallel = ~10 minutes total
3. ✅ **Reliable** - Built-in error handling and retry
4. ✅ **Maintainable** - Single template for all accounts
5. ✅ **AWS Best Practice** - Recommended by AWS for this use case

The Terraform automated approach (`create_cross_account_roles = true`) is **not suitable** for 50 accounts due to:
- ❌ Requires 50 provider aliases (unmaintainable)
- ❌ Sequential deployment (very slow)
- ❌ Complex error handling
- ❌ Not a Terraform best practice at this scale

---

**Created by:** murthy  
**Date:** 02/02/2026  
**Accounts:** 1 monitoring + 50 targets = 51 total  
**Deployment Method:** CloudFormation StackSets + Terraform
