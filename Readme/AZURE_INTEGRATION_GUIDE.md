# AWS DevOps Agent - Azure Integration Guide
## Created by murthy on 04/05/2026

## Overview

This guide provides **step-by-step instructions** to connect Azure Resources and (optionally) Azure DevOps to your existing AWS DevOps Agent Space using the **Admin Consent** method.

**Total Time:** ~20-30 minutes  
**Agent Space:** ZayodevopsAgentSpace  
**Registration Method:** Admin Consent  
**AWS Region:** us-east-1

> **Reference Docs:**
> - [Connecting Azure - Overview](https://docs.aws.amazon.com/devopsagent/latest/userguide/configuring-capabilities-for-aws-devops-agent-connecting-azure-index.html)
> - [Connecting Azure Resources](https://docs.aws.amazon.com/devopsagent/latest/userguide/connecting-azure-connecting-azure-resources.html)
> - [Connecting Azure DevOps](https://docs.aws.amazon.com/devopsagent/latest/userguide/connecting-azure-connecting-azure-devops.html)
> - [GA Announcement Blog](https://aws.amazon.com/blogs/mt/announcing-general-availability-of-aws-devops-agent/)

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS DevOps Agent console access (us-east-1)
- [ ] `ZayodevopsAgentSpace` already deployed and operational
- [ ] Azure account with access to the target subscription(s)
- [ ] Microsoft Entra ID account with **admin consent permissions** (Global Admin or Privileged Role Admin)
- [ ] Azure Portal access with permissions to assign IAM roles on the target subscription
- [ ] (Optional) `az` CLI installed if configuring AKS access
- [ ] (Optional) `kubectl` installed if configuring AKS access

---

## Phase 1: Register Azure Cloud via Admin Consent (~5 minutes)

> 📍 **Where:** AWS Management Console

This registers the Azure integration at the **AWS account level**. You only do this once.

### Step 1.1: Navigate to Capability Providers

1. Sign in to the [AWS Management Console](https://console.aws.amazon.com/aidevops/)
2. Make sure you are in **us-east-1** region
3. In the left navigation, click **Capability Providers**

### Step 1.2: Start Azure Cloud Registration

1. Locate the **Azure Cloud** section on the page
2. Click **Register**
3. Select **Admin Consent** as the registration method

### Step 1.3: Complete Admin Consent in Microsoft Entra

1. You will be **redirected to the Microsoft Entra admin consent page**
2. Sign in with your Entra account that has admin consent permissions
   - This must be a **user principal account** (not a service account)
   - Typically a Global Admin or Privileged Role Admin
3. Review the permissions being requested by the AWS DevOps Agent application
4. Click **Accept** to grant consent

> **What's happening:** You are authorizing the AWS DevOps Agent managed Entra application to access your Azure tenant. This does NOT grant access to any resources yet — that comes in Phase 2.

### Step 1.4: Complete User Authorization

1. After admin consent, you'll be prompted for **user authorization**
   - This verifies your identity as a member of the authorized tenant
2. Sign in with an account belonging to the **same Azure tenant**
3. After authorization, you are **redirected back** to the AWS DevOps Agent console
4. You should see a **success status** on the Capability Providers page

### Step 1.5: Verify Registration

- On the **Capability Providers** page, the Azure Cloud section should now show as **Registered**
- Note down the registration details for your records

> **Known Limitation:** Each Azure tenant can only be associated with **one AWS account** at a time via Admin Consent. To move it to a different AWS account later, you must deregister first.

---

## Phase 2: Create and Assign Least-Privilege Role (~10 minutes)

> 📍 **Where:** Azure Portal (portal.azure.com) — ALL steps in this phase are in Azure, not AWS

This phase has two parts: first you **create** a custom role definition (2.1), then you **assign** it to the AWS DevOps Agent service principal (2.2). Both parts are required — creating the role alone does nothing until you assign it.

### Step 2.1: Create the Custom Role Definition (Azure Portal)

> This step only creates the role — it does NOT assign it to anyone yet.

1. Open the [Azure Portal](https://portal.azure.com)
2. Navigate to **Subscriptions** → select your target subscription
3. Go to **Access Control (IAM)** in the left menu
4. Click **+ Add** → **Add custom role**
5. Select **Start from JSON** and paste the following:

```json
{
  "Name": "AWS DevOps Agent - Azure Reader",
  "Description": "Least-privilege read-only access for AWS DevOps Agent incident investigations.",
  "Actions": [
    "Microsoft.AlertsManagement/*/read",
    "Microsoft.Compute/*/read",
    "Microsoft.ContainerRegistry/*/read",
    "Microsoft.ContainerService/*/read",
    "Microsoft.ContainerService/managedClusters/commandResults/read",
    "Microsoft.DocumentDB/*/read",
    "Microsoft.Insights/*/read",
    "Microsoft.KeyVault/vaults/read",
    "Microsoft.ManagedIdentity/*/read",
    "Microsoft.Monitor/*/read",
    "Microsoft.Network/*/read",
    "Microsoft.OperationalInsights/*/read",
    "Microsoft.ResourceGraph/resources/read",
    "Microsoft.ResourceHealth/*/read",
    "Microsoft.Resources/*/read",
    "Microsoft.Sql/*/read",
    "Microsoft.Storage/*/read",
    "Microsoft.Web/*/read"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<YOUR-SUBSCRIPTION-ID>"
  ]
}
```

6. Replace `<YOUR-SUBSCRIPTION-ID>` with your actual Azure subscription ID
7. Click **Review + create** → **Create**

> **Alternative (quick path):** If you want to skip creating a custom role, you can use the built-in **Reader** role in Step 2.2 instead. The custom role is recommended for production.

### Step 2.2: Assign the Role to AWS DevOps Agent (Azure Portal)

> **Why this is needed:** Step 2.1 only created the role definition. This step actually grants it to the AWS DevOps Agent service principal so the agent can read your Azure resources.

1. Still in Azure Portal → your subscription → **Access Control (IAM)**
2. Click **+ Add** → **Add role assignment**
3. In the **Role** tab:
   - Search for `AWS DevOps Agent - Azure Reader` (the custom role you created in Step 2.1)
   - Select it and click **Next**
4. In the **Members** tab:
   - Select **User, group, or service principal**
   - Click **+ Select members**
   - Search for **AWS DevOps Agent**
   - Select the application and click **Select**
5. Click **Review + assign** → **Review + assign**

### Step 2.3: Verify the Role Assignment (Azure Portal)

1. Still in Azure Portal → your subscription → **Access Control (IAM)** → **Role assignments** tab
2. Search for **AWS DevOps Agent**
3. Confirm it shows the `AWS DevOps Agent - Azure Reader` role assigned

---

## Phase 3: Associate Azure Subscription with ZayodevopsAgentSpace (~2 minutes)

> 📍 **Where:** AWS Management Console

### Step 3.1: Open Your Agent Space

1. Go back to the [AWS DevOps Agent console](https://console.aws.amazon.com/aidevops/)
2. Click on **ZayodevopsAgentSpace**

### Step 3.2: Add Azure Subscription

1. Go to the **Capabilities** tab
2. Find the **Secondary sources** section
3. Click **Add**
4. Select **Azure**
5. Enter your **Azure Subscription ID**
   - Find this in Azure Portal → Subscriptions → copy the Subscription ID
6. Click **Add**

### Step 3.3: Verify Association

- The **Secondary sources** section should now list your Azure subscription
- You can add multiple subscriptions by repeating Step 3.2

---

## Phase 4: AKS Access Setup (Optional, ~10 minutes)

> 📍 **Where:** Azure Portal + CLI

Skip this phase if you don't have Azure Kubernetes Service (AKS) clusters.

### Step 4.1: Assign AKS Cluster User Role (Azure Portal)

1. In Azure Portal → **Subscriptions** → your subscription → **Access Control (IAM)**
2. Click **+ Add** → **Add role assignment**
3. Search for **Azure Kubernetes Service Cluster User Role**
4. Select it → **Next**
5. Click **+ Select members** → search for **AWS DevOps Agent** → **Select**
6. **Review + assign**

> This covers all AKS clusters in the subscription. To scope to specific clusters, assign at the resource group or individual cluster level instead.

### Step 4.2: Configure Kubernetes API Access

Choose **one** of the following options:

#### Option A: Azure RBAC for Kubernetes (Recommended)

1. In Azure Portal → navigate to your AKS cluster
2. Go to **Settings** → **Security configuration** → **Authentication and authorization**
3. Select **Azure RBAC** (enable it if not already)
4. Go back to **Subscriptions** → **Access Control (IAM)**
5. Add role assignment → **Azure Kubernetes Service RBAC Reader** → assign to **AWS DevOps Agent**

#### Option B: Azure AD + Kubernetes RBAC (Per-Cluster)

Use this if your cluster uses default Azure AD auth and you don't want to enable Azure RBAC.

1. Create a file called `devops-agent-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: devops-agent-reader
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods", "pods/log", "services", "events", "nodes"]
    verbs: ["get", "list"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list"]
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods", "nodes"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devops-agent-reader-binding
subjects:
  - kind: User
    name: "<SERVICE_PRINCIPAL_OBJECT_ID>"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: devops-agent-reader
  apiGroup: rbac.authorization.k8s.io
```

2. Find the Service Principal Object ID:
   - Azure Portal → **Entra ID** → **Enterprise Applications** → search for **AWS DevOps Agent**
   - Copy the **Object ID**
   - Replace `<SERVICE_PRINCIPAL_OBJECT_ID>` in the YAML

3. Apply to each AKS cluster:

```bash
# Get credentials for the cluster
az aks get-credentials --resource-group <RESOURCE-GROUP> --name <CLUSTER-NAME>

# Apply the RBAC manifest
kubectl apply -f devops-agent-reader.yaml
```

4. Repeat for each AKS cluster you want the agent to access.

---

## Phase 5: Test the Integration (~5 minutes)

> 📍 **Where:** AWS DevOps Agent Console

### Step 5.1: Run an On-Demand Investigation

1. In the AWS DevOps Agent console → **ZayodevopsAgentSpace**
2. Go to the **On-demand SRE** chat interface
3. Try these queries to verify Azure connectivity:

```
What Azure resources are in my environment?
```

```
Show me the health status of my Azure subscription.
```

```
List all Azure VMs and their current status.
```

### Step 5.2: Verify Resource Discovery

- The agent should be able to list Azure resources from your subscription
- If you configured AKS access, try:

```
List all AKS clusters and their node status.
```

### Step 5.3: Test Incident Correlation

- If you have a recent incident that involved Azure resources, use the agent to reinvestigate it
- The agent should now correlate data across both AWS and Azure environments

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Admin consent redirect fails | Ensure you're using a user principal account with Global Admin or Privileged Role Admin permissions in **Entra ID** |
| Agent can't see Azure resources | Verify the role assignment in **Azure Portal** → Access Control (IAM) → Role assignments |
| Subscription association fails | Check that the Azure Cloud registration shows as "Registered" on the Capability Providers page in **AWS Console** |
| AKS clusters not visible | Ensure both ARM-level role (Cluster User) and Kubernetes API access (RBAC Reader) are assigned in **Azure Portal** |
| "Unauthorized" errors in investigations | The custom role may be missing a required action — try switching to the built-in Reader role in **Azure Portal** to confirm |

---

## Quick Reference: What Was Configured

| Component | Where | What |
|-----------|-------|------|
| Azure Cloud Registration | 📍 **AWS Console** → Capability Providers | Admin Consent with your Azure tenant |
| Custom Azure Role | 📍 **Azure Portal** → Subscription → IAM | `AWS DevOps Agent - Azure Reader` role definition |
| Role Assignment | 📍 **Azure Portal** → Subscription → IAM | AWS DevOps Agent service principal assigned the custom role |
| Subscription Association | 📍 **AWS Console** → ZayodevopsAgentSpace → Capabilities | Azure subscription linked as secondary source |
| AKS Access (optional) | 📍 **Azure Portal** + kubectl | Cluster User Role + RBAC Reader or K8s RBAC |

---

## Next Steps

- [ ] Monitor the first few Azure-related investigations for accuracy
- [ ] Add additional Azure subscriptions if needed (repeat Phase 3)
- [ ] Consider setting up [Azure DevOps integration](https://docs.aws.amazon.com/devopsagent/latest/userguide/connecting-azure-connecting-azure-devops.html) if your teams use ADO pipelines
- [ ] Review [Best Practices for Deploying AWS DevOps Agent](https://aws.amazon.com/blogs/devops/best-practices-for-deploying-aws-devops-agent-in-production/)
