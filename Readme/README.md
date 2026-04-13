# AWS DevOps Agent Terraform Configuration

This Terraform configuration replicates the AWS DevOps Agent CLI onboarding guide setup, providing Infrastructure as Code for deploying and managing AWS DevOps Agent resources.

## Overview

AWS DevOps Agent helps you monitor and manage your AWS infrastructure using AI-powered insights. This Terraform configuration automates the setup process described in the [CLI onboarding guide](https://docs.aws.amazon.com/devopsagent/latest/userguide/getting-started-with-aws-devops-agent-cli-onboarding-guide.html).

### What's New (Updated by murthy on 02/02/2026)

**Automated Cross-Account Role Creation**: This configuration now supports automatic creation of cross-account IAM roles in target accounts during deployment. No more manual role creation steps!

**Key Features:**
- ✅ Single `terraform apply` deploys everything
- ✅ Automatically creates `DevOpsAgentCrossAccountRole` in target accounts
- ✅ Handles IAM propagation delays automatically
- ✅ Supports both automated and manual cross-account setup
- ✅ Proper trust policies with ExternalId for security

**How it works:**
1. Terraform uses provider aliases to assume a role in target accounts
2. Creates the required cross-account role with proper trust policy
3. Attaches necessary policies (AIOpsAssistantPolicy + additional permissions)
4. Sets up associations between monitoring and target accounts
5. All in a single deployment!

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate permissions
- AWS DevOps Agent is only available in `us-east-1` region
- Required IAM permissions for creating roles and policies
- **For automated cross-account setup**: An assume role in target accounts (e.g., `OrganizationAccountAccessRole`)

## Resources Created

This configuration creates the following resources:

### IAM Resources
- **DevOpsAgentRole-AgentSpace**: IAM role for the Agent Space with required permissions
- **DevOpsAgentRole-WebappAdmin**: IAM role for the Operator App
- Associated policies and trust relationships

### DevOps Agent Resources
- **Agent Space**: The main container for your DevOps Agent configuration
- **AWS Account Association**: Links your AWS account for monitoring
- **Operator App**: (Optional) Enables the web-based operator interface
- **External Account Associations**: (Optional) For cross-account monitoring

## Usage

### Option 1: Single Deployment with Automated Cross-Account Setup (Recommended - Updated by murthy on 02/02/2026)

This option automatically creates cross-account roles in target accounts during deployment.

**Prerequisites:**
- Access role in target account (e.g., `OrganizationAccountAccessRole`) that allows monitoring account to assume it
- Permissions to create IAM roles in both monitoring and target accounts

1. **Clone and Configure**
   ```bash
   git clone <this-repo>
   cd sample-aws-devops-agent-terraform
   ```

2. **Configure Variables**
   Edit `terraform.tfvars`:
   ```hcl
   agent_space_name = "MyCompanyAgentSpace"
   agent_space_description = "DevOps monitoring for production workloads"
   enable_operator_app = true
   
   # Enable automated cross-account role creation
   create_cross_account_roles = true
   
   # Configure target accounts
   external_accounts = {
     "123456789012" = {
       account_id = "123456789012"
       role_arn   = "arn:aws:iam::123456789012:role/OrganizationAccountAccessRole"
     }
   }
   ```

3. **Deploy Everything**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
   This will:
   - Create Agent Space and IAM roles in monitoring account
   - Automatically create `DevOpsAgentCrossAccountRole` in target accounts
   - Set up associations for all accounts
   - Handle IAM propagation delays automatically

4. **Complete Setup**
   ```bash
   ./post-deploy.sh
   ```
   This script will:
   - Configure AWS DevOps Agent CLI if needed
   - Optionally enable the Operator App
   - Provide verification commands

5. **Clean Up (when needed)**
   ```bash
   ./cleanup.sh
   ```

### Option 2: Two-Phase Deployment (Manual Cross-Account Setup)

Use this if you don't have an assume role in target accounts or prefer manual control.

1. **Phase 1: Deploy Monitoring Account**
   ```bash
   git clone <this-repo>
   cd sample-aws-devops-agent-terraform
   cp terraform.tfvars.example terraform.tfvars
   ```
   
   Edit `terraform.tfvars` (leave external_accounts commented out):
   ```hcl
   agent_space_name = "MyCompanyAgentSpace"
   agent_space_description = "DevOps monitoring for production workloads"
   enable_operator_app = true
   create_cross_account_roles = false
   ```
   
   Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Phase 2: Create Cross-Account Roles Manually**
   
   Get the Agent Space ID:
   ```bash
   AGENT_SPACE_ID=$(terraform output -raw agent_space_id)
   MONITORING_ACCOUNT=$(terraform output -raw account_id)
   AGENTSPACE_ROLE_ARN=$(terraform output -raw devops_agentspace_role_arn)
   ```
   
   In each target account, create the role:
   ```bash
   # Switch to target account
   aws iam create-role \
     --role-name DevOpsAgentCrossAccountRole \
     --assume-role-policy-document '{
       "Version": "2012-10-17",
       "Statement": [{
         "Effect": "Allow",
         "Principal": {"AWS": "'$AGENTSPACE_ROLE_ARN'"},
         "Action": "sts:AssumeRole",
         "Condition": {
           "StringEquals": {
             "sts:ExternalId": "arn:aws:aidevops:us-east-1:'$MONITORING_ACCOUNT':agentspace/'$AGENT_SPACE_ID'"
           }
         }
       }]
     }'
   
   aws iam attach-role-policy \
     --role-name DevOpsAgentCrossAccountRole \
     --policy-arn arn:aws:iam::aws:policy/AIOpsAssistantPolicy
   ```

3. **Phase 3: Add External Accounts**
   
   Edit `terraform.tfvars` and add:
   ```hcl
   external_accounts = {
     "123456789012" = {
       account_id = "123456789012"
       role_arn   = "arn:aws:iam::123456789012:role/OrganizationAccountAccessRole"
     }
   }
   ```
   
   Apply again:
   ```bash
   terraform apply
   ```

4. **Verify Setup**
   ```bash
   aws devopsagent list-agent-spaces \
     --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
     --region us-east-1
   ```

## Configuration Options

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region (must be us-east-1) | `us-east-1` | Yes |
| `agent_space_name` | Name for the Agent Space | `MyAgentSpace` | No |
| `agent_space_description` | Description for the Agent Space | `AgentSpace for monitoring my application` | No |
| `enable_operator_app` | Enable the operator web app | `true` | No |
| `auth_flow` | Authentication flow (iam/idc) | `iam` | No |
| `create_cross_account_roles` | Automatically create roles in target accounts | `false` | No |
| `external_accounts` | Map of external AWS accounts with assume role ARNs | `{}` | No |
| `tags` | Tags for all resources | See variables.tf | No |

### Cross-Account Monitoring

**Updated by murthy on 02/02/2026**

Three approaches for cross-account monitoring, depending on your scale:

#### Approach 1: CloudFormation StackSets (Recommended for 10+ Accounts)

**Best for:** 10-100+ target accounts

Uses AWS CloudFormation StackSets to deploy cross-account roles to multiple accounts simultaneously.

**Advantages:**
- ✅ Scales to unlimited accounts
- ✅ Parallel deployment (10 accounts at a time)
- ✅ Built-in retry and error handling
- ✅ Easy to update roles across all accounts
- ✅ AWS best practice for multi-account deployments

**See:** `cloudformation/README.md` and `cloudformation/STACKSET_DEPLOYMENT_GUIDE.md` for complete instructions.

**Quick Steps:**
1. Deploy Terraform (monitoring account only)
2. Deploy StackSet via AWS Console to all target accounts
3. Update terraform.tfvars with all account IDs
4. Run `terraform apply` to create associations

#### Approach 2: Automated with Terraform (For 1-3 Accounts)

Terraform automatically creates cross-account roles in target accounts.

**Prerequisites:**
- An assume role in each target account (e.g., `OrganizationAccountAccessRole`)
- This role must allow the monitoring account to assume it

**Configuration:**

```hcl
# In terraform.tfvars
create_cross_account_roles = true

external_accounts = {
  "123456789012" = {
    account_id = "123456789012"
    role_arn   = "arn:aws:iam::123456789012:role/OrganizationAccountAccessRole"
  }
}
```

**Deploy:**
```bash
terraform apply
```

**Limitation:** Only practical for 1-3 accounts due to provider alias complexity.

#### Approach 3: Manual (For Any Number of Accounts)

Use this if you don't have an assume role or prefer manual control.

**Step 1: Deploy without external accounts**
```bash
# Leave external_accounts commented out in terraform.tfvars
terraform apply
```

**Step 2: Create roles manually in target accounts**

Get required values:
```bash
AGENT_SPACE_ID=$(terraform output -raw agent_space_id)
MONITORING_ACCOUNT=$(terraform output -raw account_id)
AGENTSPACE_ROLE_ARN=$(terraform output -raw devops_agentspace_role_arn)
```

In each target account:
```bash
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "$AGENTSPACE_ROLE_ARN"},
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "sts:ExternalId": "arn:aws:aidevops:us-east-1:$MONITORING_ACCOUNT:agentspace/$AGENT_SPACE_ID"
      }
    }
  }]
}
EOF

aws iam create-role \
  --role-name DevOpsAgentCrossAccountRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name DevOpsAgentCrossAccountRole \
  --policy-arn arn:aws:iam::aws:policy/AIOpsAssistantPolicy
```

**Step 3: Update terraform.tfvars and apply**
```hcl
external_accounts = {
  "123456789012" = {
    account_id = "123456789012"
    role_arn   = "arn:aws:iam::123456789012:role/OrganizationAccountAccessRole"
  }
}
```

```bash
terraform apply
```

## Outputs

The configuration provides several useful outputs:

- `agent_space_id`: The ID of your Agent Space
- `agent_space_arn`: The ARN of your Agent Space  
- `devops_agentspace_role_arn`: ARN of the Agent Space IAM role
- `devops_operator_role_arn`: ARN of the Operator App IAM role
- `external_account_role_arns`: ARNs of cross-account roles created in target accounts (if automated)
- `manual_setup_instructions`: Next steps and verification commands

## Accessing DevOps Agent

After deployment:

1. **AWS Console**: Visit https://console.aws.amazon.com/devopsagent/
2. **CLI**: Use the AWS CLI with the DevOps Agent service model
3. **Operator App**: If enabled, access through the AWS console

## Limitations

- AWS DevOps Agent is currently in preview
- Only available in `us-east-1` region
- Automated cross-account role creation requires an assume role in target accounts
- Single provider alias supports one target account at a time (for multiple accounts, manual setup recommended)
- Cross-account roles must be created manually in external accounts if not using automated approach

## Troubleshooting

### Common Issues

1. **Region Error**: Ensure you're using `us-east-1`
2. **Permission Errors**: Verify your AWS credentials have IAM permissions
3. **Role Trust Issues**: Check that trust policies include correct account IDs
4. **Cross-Account Access Denied**: 
   - Verify `OrganizationAccountAccessRole` exists in target account
   - Check trust policy allows monitoring account to assume it
   - Ensure `create_cross_account_roles = true` in terraform.tfvars
5. **Association Failures**: Wait 2-3 minutes for IAM propagation, then retry `terraform apply`

### Verification Commands

```bash
# List Agent Spaces
aws devopsagent list-agent-spaces \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1

# Get specific Agent Space
aws devopsagent get-agent-space \
  --agent-space-id <AGENT_SPACE_ID> \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1

# List associations
aws devopsagent list-associations \
  --agent-space-id <AGENT_SPACE_ID> \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.