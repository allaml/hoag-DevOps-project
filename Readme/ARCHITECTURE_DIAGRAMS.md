# AWS DevOps Agent Architecture Diagrams

## Diagram 1: High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                         👤 DevOps Administrator                              │
│                                                                              │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   │ Manages via Terraform & CloudFormation
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      MONITORING ACCOUNT (zayo-ct)                            │
│                         Account ID: 414351351247                             │
│                                                                              │
│  ┌────────────────────────────┐         ┌──────────────────────────────┐   │
│  │      TERRAFORM             │         │   CLOUDFORMATION STACKSETS   │   │
│  │                            │         │                              │   │
│  │  Manages:                  │         │  Deploys:                    │   │
│  │  ┌──────────────────────┐ │         │  ┌────────────────────────┐ │   │
│  │  │ 🤖 DevOps Agent      │ │         │  │ 📋 Cross-Account       │ │   │
│  │  │    Space             │ │         │  │    Role Template       │ │   │
│  │  │                      │ │         │  │                        │ │   │
│  │  │ • AI Engine          │ │         │  │ • IAM Role             │ │   │
│  │  │ • Monitoring Hub     │ │         │  │ • Trust Policy         │ │   │
│  │  │ • Insights Dashboard │ │         │  │ • Permissions          │ │   │
│  │  └──────────────────────┘ │         │  └────────────────────────┘ │   │
│  │                            │         │                              │   │
│  │  ┌──────────────────────┐ │         │  Deployment:                 │   │
│  │  │ 🔐 IAM Roles         │ │         │  • Parallel to all accounts  │   │
│  │  │                      │ │         │  • 10-15 minutes             │   │
│  │  │ • DevOpsAgentRole    │ │         │  • Automatic retry           │   │
│  │  │ • AssumeRole perms   │ │         │                              │   │
│  │  └──────────────────────┘ │         └──────────────────────────────┘   │
│  │                            │                                             │
│  │  ┌──────────────────────┐ │                                             │
│  │  │ 🔗 Associations      │ │                                             │
│  │  │                      │ │                                             │
│  │  │ • Links to 34 accts  │ │                                             │
│  │  │ • Monitoring config  │ │                                             │
│  │  └──────────────────────┘ │                                             │
│  └────────────────────────────┘                                             │
│                                                                              │
└──────────────────────────────────┬───────────────────────────────────────────┘
                                   │
                                   │ Assumes Roles & Monitors
                                   │ (with External ID)
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TARGET ACCOUNTS (34 Total)                           │
│                            Hub2.0 OU Structure                               │
│                                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐ │
│  │    DEV OU            │  │    TEST OU           │  │    PROD OU       │ │
│  │  (11 accounts)       │  │  (12 accounts)       │  │  (11 accounts)   │ │
│  │                      │  │                      │  │                  │ │
│  │  Each account has:   │  │  Each account has:   │  │  Each has:       │ │
│  │                      │  │                      │  │                  │ │
│  │  🔐 IAM Role         │  │  🔐 IAM Role         │  │  🔐 IAM Role     │ │
│  │  DevOpsAgent         │  │  DevOpsAgent         │  │  DevOpsAgent     │ │
│  │  CrossAccountRole    │  │  CrossAccountRole    │  │  CrossAccountRole│ │
│  │                      │  │                      │  │                  │ │
│  │  Trust Policy:       │  │  Trust Policy:       │  │  Trust Policy:   │ │
│  │  • Principal: 414... │  │  • Principal: 414... │  │  • Principal:... │ │
│  │  • ExternalId: xxx   │  │  • ExternalId: xxx   │  │  • ExternalId:..│ │
│  │                      │  │                      │  │                  │ │
│  │  Monitors:           │  │  Monitors:           │  │  Monitors:       │ │
│  │  ☁️  EC2             │  │  ☁️  EC2             │  │  ☁️  EC2         │ │
│  │  λ  Lambda           │  │  λ  Lambda           │  │  λ  Lambda       │ │
│  │  🗄️  RDS             │  │  🗄️  RDS             │  │  🗄️  RDS         │ │
│  │  📦 S3               │  │  📦 S3               │  │  📦 S3           │ │
│  │  📊 CloudWatch       │  │  📊 CloudWatch       │  │  📊 CloudWatch   │ │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Diagram 2: Security & Access Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STEP 1: AUTHENTICATION                                    │
│                                                                              │
│  DevOps Agent Space (Monitoring Account)                                    │
│  ├─ Uses: DevOpsAgentRole                                                   │
│  └─ Credentials: IAM Role (no long-term keys)                               │
│                                                                              │
└──────────────────────────────────┬───────────────────────────────────────────┘
                                   │
                                   │ sts:AssumeRole Request
                                   │ + External ID
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STEP 2: AUTHORIZATION CHECK                               │
│                                                                              │
│  Target Account IAM (e.g., 608649261817)                                    │
│                                                                              │
│  Trust Policy Validation:                                                   │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ {                                                                   │    │
│  │   "Effect": "Allow",                                                │    │
│  │   "Principal": {                                                    │    │
│  │     "AWS": "arn:aws:iam::414351351247:role/DevOpsAgentRole"        │    │
│  │   },                                                                │    │
│  │   "Action": "sts:AssumeRole",                                       │    │
│  │   "Condition": {                                                    │    │
│  │     "StringEquals": {                                               │    │
│  │       "sts:ExternalId": "unique-external-id-12345"                  │    │
│  │     }                                                                │    │
│  │   }                                                                 │    │
│  │ }                                                                   │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ✅ Principal matches: 414351351247                                          │
│  ✅ External ID matches: unique-external-id-12345                            │
│  ✅ Action allowed: sts:AssumeRole                                           │
│                                                                              │
└──────────────────────────────────┬───────────────────────────────────────────┘
                                   │
                                   │ Temporary Credentials Issued
                                   │ (Valid for 1 hour)
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STEP 3: RESOURCE ACCESS                                   │
│                                                                              │
│  DevOps Agent (with assumed role credentials)                               │
│                                                                              │
│  Allowed Actions (Read-Only):                                               │
│  ✅ ec2:Describe*                                                            │
│  ✅ lambda:Get*, lambda:List*                                                │
│  ✅ rds:Describe*                                                            │
│  ✅ s3:GetBucketLocation, s3:ListBucket                                      │
│  ✅ cloudwatch:Get*, cloudwatch:List*                                        │
│  ✅ cloudtrail:LookupEvents                                                  │
│  ✅ iam:Get*, iam:List* (policies only)                                      │
│                                                                              │
│  Denied Actions:                                                             │
│  ❌ Any Create, Update, Delete operations                                    │
│  ❌ s3:GetObject (cannot read S3 file contents)                              │
│  ❌ iam:CreateRole, iam:DeleteRole                                           │
│  ❌ ec2:TerminateInstances                                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Diagram 3: Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHASE 1: MONITORING ACCOUNT                          │
│                              (5-10 minutes)                                  │
│                                                                              │
│  Step 1: Initialize Terraform                                               │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ $ cd aws-devops-agent-terraform                                     │    │
│  │ $ terraform init                                                    │    │
│  │ $ terraform plan                                                    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  Step 2: Deploy Core Resources                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ $ terraform apply                                                   │    │
│  │                                                                     │    │
│  │ Creates:                                                            │    │
│  │ ✅ DevOps Agent Space                                               │    │
│  │ ✅ DevOpsAgentRole (monitoring account)                             │    │
│  │ ✅ IAM policies and permissions                                     │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  Step 3: Save Outputs                                                       │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ $ terraform output -raw agent_space_arn                             │    │
│  │ $ terraform output -raw devops_agentspace_role_arn                  │    │
│  │ $ terraform output -raw external_id                                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────┬───────────────────────────────────────────┘
                                   │
                                   │ Outputs used as inputs
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHASE 2: TARGET ACCOUNTS                             │
│                              (10-15 minutes)                                 │
│                                                                              │
│  Step 1: Prepare StackSet                                                   │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ Navigate to: AWS Console → CloudFormation → StackSets              │    │
│  │                                                                     │    │
│  │ Upload: cloudformation/cross-account-role-stackset.yaml            │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  Step 2: Configure Parameters                                               │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ MonitoringAccountId: 414351351247                                   │    │
│  │ DevOpsAgentRoleArn: <from terraform output>                         │    │
│  │ ExternalId: <from terraform output>                                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  Step 3: Deploy to Accounts                                                 │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ Deployment Target:                                                  │    │
│  │ • Organization: o-4qyhe0u74u                                        │    │
│  │ • OU: Hub2.0 (ou-775j-prjablf0)                                     │    │
│  │ • Regions: us-east-1                                                │    │
│  │                                                                     │    │
│  │ StackSet deploys in PARALLEL to:                                   │    │
│  │ ├─ Dev OU (11 accounts)    ⏱️  ~3 min                              │    │
│  │ ├─ Test OU (12 accounts)   ⏱️  ~3 min                              │    │
│  │ └─ Prod OU (11 accounts)   ⏱️  ~3 min                              │    │
│  │                                                                     │    │
│  │ Total: ~10 minutes (parallel deployment)                           │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  Step 4: Verify Deployment                                                  │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ Check StackSet Status:                                              │    │
│  │ ✅ 34/34 Stack Instances: CURRENT                                   │    │
│  │ ✅ 0 Failed                                                          │    │
│  │ ✅ All roles created successfully                                   │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────┬───────────────────────────────────────────┘
                                   │
                                   │ Roles ready for association
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHASE 3: ASSOCIATIONS                                │
│                              (5 minutes)                                     │
│                                                                              │
│  Step 1: Generate Account List                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ $ bash cloudformation/generate-external-accounts.sh                 │    │
│  │                                                                     │    │
│  │ Generates terraform configuration for 34 accounts                  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  Step 2: Update Terraform Config                                            │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ Add to terraform.tfvars:                                            │    │
│  │                                                                     │    │
│  │ external_accounts = [                                               │    │
│  │   {                                                                 │    │
│  │     account_id = "608649261817"                                     │    │
│  │     role_arn = "arn:aws:iam::608649261817:role/..."                │    │
│  │   },                                                                │    │
│  │   ... (33 more accounts)                                            │    │
│  │ ]                                                                   │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  Step 3: Create Associations                                                │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ $ terraform apply                                                   │    │
│  │                                                                     │    │
│  │ Creates 34 account associations                                    │    │
│  │ Links Agent Space to all target accounts                           │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  ✅ DEPLOYMENT COMPLETE                                                      │
│  • Total time: ~30 minutes                                                  │
│  • 34 accounts monitored                                                    │
│  • Zero manual configuration                                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Diagram 4: Monitoring Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TARGET ACCOUNT RESOURCES                             │
│                                                                              │
│  ☁️  EC2 Instances    λ  Lambda Functions    🗄️  RDS Databases             │
│  📦 S3 Buckets        🔐 IAM Roles           🌐 VPC Resources               │
│                                                                              │
│                              │                                               │
│                              │ Emit Metrics & Logs                           │
│                              ▼                                               │
│                                                                              │
│  📊 CloudWatch          📝 CloudTrail          💰 Cost Explorer             │
│  • Metrics              • API Calls            • Usage Data                 │
│  • Logs                 • Events               • Cost Data                  │
│  • Alarms               • Audit Trail          • Trends                     │
│                                                                              │
└──────────────────────────────────┬───────────────────────────────────────────┘
                                   │
                                   │ DevOps Agent Queries
                                   │ (via assumed role)
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEVOPS AGENT SPACE                                   │
│                        (Monitoring Account)                                  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    DATA COLLECTION ENGINE                           │    │
│  │                                                                     │    │
│  │  Collects from all 34 accounts:                                    │    │
│  │  • Resource configurations                                          │    │
│  │  • Performance metrics                                              │    │
│  │  • Cost and usage data                                              │    │
│  │  • Security findings                                                │    │
│  │  • Operational events                                               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    AI ANALYSIS ENGINE                               │    │
│  │                                                                     │    │
│  │  🤖 Machine Learning Models:                                        │    │
│  │  • Anomaly detection                                                │    │
│  │  • Pattern recognition                                              │    │
│  │  • Predictive analytics                                             │    │
│  │  • Root cause analysis                                              │    │
│  │  • Optimization recommendations                                     │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    INSIGHTS GENERATION                              │    │
│  │                                                                     │    │
│  │  Generates:                                                         │    │
│  │  💡 Cost optimization opportunities                                 │    │
│  │  🔒 Security recommendations                                        │    │
│  │  ⚡ Performance improvements                                        │    │
│  │  🎯 Operational best practices                                      │    │
│  │  📈 Trend analysis and forecasts                                    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    NOTIFICATION ENGINE                              │    │
│  │                                                                     │    │
│  │  Sends alerts via:                                                  │    │
│  │  📧 Email                                                            │    │
│  │  💬 Slack/Teams                                                      │    │
│  │  📱 SNS                                                              │    │
│  │  🔔 EventBridge                                                      │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────┬───────────────────────────────────────────┘
                                   │
                                   │ Presents insights
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEVOPS TEAM                                          │
│                                                                              │
│  👤 DevOps Engineers                                                         │
│  • View dashboards                                                           │
│  • Query with natural language                                              │
│  • Act on recommendations                                                   │
│  • Track improvements                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Diagram 5: Cost Breakdown

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MONTHLY COST BREAKDOWN                               │
│                         (34 Target Accounts)                                 │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ DevOps Agent Space                                                  │    │
│  │ $0.10/hour × 730 hours/month                                        │    │
│  │                                                                     │    │
│  │ ████████████████████████████████████████ $73.00                     │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ Account Associations (34 accounts)                                  │    │
│  │ $0.01/hour × 34 accounts × 730 hours/month                          │    │
│  │                                                                     │    │
│  │ ████████████████████████████████████████████████████████ $248.20    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ CloudWatch Logs (estimated)                                         │    │
│  │ ~5 GB/month × $0.50/GB                                              │    │
│  │                                                                     │    │
│  │ ██ $2.50                                                            │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ Data Transfer (estimated)                                           │    │
│  │ ~10 GB/month × $0.09/GB                                             │    │
│  │                                                                     │    │
│  │ █ $0.90                                                             │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │ TOTAL MONTHLY COST                                                  │    │
│  │                                                                     │    │
│  │ ████████████████████████████████████████████████████████ $324.60    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Cost per account: $324.60 ÷ 34 = $9.55/month                               │
│                                                                              │
│  ROI Potential:                                                              │
│  • Cost optimization savings: $1,000-5,000/month                            │
│  • Reduced incident response time: 50-70%                                   │
│  • Prevented outages: Priceless                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---
