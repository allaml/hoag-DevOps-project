# AWS DevOps Agent — Azure Integration Setup Guide

## Prerequisites
- Azure tenant with Global Admin or Cloud Application Admin access
- AWS DevOps Agent Space already created
- Target Azure subscription ID

## Environment Details

| Item | Value |
|---|---|
| Azure Tenant ID | `b8ea64f9-f20e-438d-baa6-a090cb1947b9` |
| Tenant Domain | zayo.com |
| Target Subscription | `167f5b70-5c4c-4e39-a0e9-2a7e43f42579` (zayo-enterprise-application-services-prod-subs-01) |
| AWS App Client ID | `44659a95-bb9b-4119-ac67-65d547605eb2` |
| Service Principal Object ID | `50f9cddd-f0f3-4a30-9741-a0203abbad7a` |
| App Publisher | Amazon Corporate LLC (Verified) |
| Agent Space ID | `fe2370ca-ed86-43e3-b8e4-33af40b5605b` |

---

## Step 1: Register Azure Subscription in DevOps Agent (AWS Console)

In the AWS DevOps Agent console:

1. Navigate to **Agent Space → Capabilities → Cloud**
2. Click **"Add"** under Secondary sources
3. Select **"Azure subscription"**
4. Enter the Azure subscription ID: `167f5b70-5c4c-4e39-a0e9-2a7e43f42579`
5. Provide a registration name (e.g., `Zayo-AWS-AzureWL`)
6. This triggers an OAuth2 flow that redirects to Azure for authentication

This automatically creates the Enterprise Application **"AWS DevOps Agent - Azure Cloud"** in your Azure tenant.

---

## Step 2: Verify Enterprise Application in Azure (Entra ID)

The registration creates a service principal in your tenant. Verify it:

```bash
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals?\$filter=appId eq '44659a95-bb9b-4119-ac67-65d547605eb2'" \
  --query "value[].{displayName:displayName, appId:appId, id:id, publisher:verifiedPublisher.displayName}" \
  --output table
```

Expected output:

| DisplayName | AppId | Publisher |
|---|---|---|
| AWS DevOps Agent - Azure Cloud | 44659a95-bb9b-4119-ac67-65d547605eb2 | Amazon Corporate LLC |

Key details of the service principal:
- **Service Principal Type:** Application
- **Sign-in Audience:** AzureADandPersonalMicrosoftAccount (multi-tenant)
- **Reply URLs:** AWS DevOps Agent callback endpoints across multiple AWS regions
- **Tag:** WindowsAzureActiveDirectoryIntegratedApp

---

## Step 3: Grant Admin Consent for Delegated Permissions

The app requires `user_impersonation` delegated permission on **Azure Resource Manager**. A **Global Admin** or **Cloud Application Admin** must grant consent.

### Option A — Via Consent URL (Recommended)

Open this URL in a browser and approve:

```
https://login.microsoftonline.com/b8ea64f9-f20e-438d-baa6-a090cb1947b9/adminconsent?client_id=44659a95-bb9b-4119-ac67-65d547605eb2
```

### Option B — Via Entra ID Portal

1. Go to **Entra ID → Enterprise Applications**
2. Search for **"AWS DevOps Agent - Azure Cloud"**
3. Go to **Permissions** tab
4. Click **"Grant admin consent for zayo.com"**

### Option C — Via CLI

```bash
az ad app permission admin-consent --id 44659a95-bb9b-4119-ac67-65d547605eb2
```

### Verify Consent

```bash
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/50f9cddd-f0f3-4a30-9741-a0203abbad7a/oauth2PermissionGrants" \
  --output json
```

Expected output:
- `consentType`: `AllPrincipals`
- `scope`: `user_impersonation`
- `resourceId` should point to **Azure Resource Manager** (`797f4846-ba00-4fd7-ba43-dac1f8f63013`)

---

## Step 4: Assign Reader Role on Target Azure Subscription

The service principal needs **RBAC Reader** access on the subscription to read resources during investigations.

```bash
az role assignment create \
  --assignee "44659a95-bb9b-4119-ac67-65d547605eb2" \
  --role "Reader" \
  --scope "/subscriptions/167f5b70-5c4c-4e39-a0e9-2a7e43f42579"
```

### Verify Role Assignment

```bash
az role assignment list \
  --subscription "167f5b70-5c4c-4e39-a0e9-2a7e43f42579" \
  --assignee "44659a95-bb9b-4119-ac67-65d547605eb2" \
  --query "[].{role:roleDefinitionName, scope:scope, createdOn:createdOn}" \
  --output table
```

Expected: `Reader` role at subscription scope.

---

## Step 5: Verify Authentication is Working

Check Azure AD sign-in logs to confirm the agent can authenticate:

```bash
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/auditLogs/signIns?\$filter=appId eq '44659a95-bb9b-4119-ac67-65d547605eb2'&\$top=5&\$orderby=createdDateTime desc" \
  --query "value[].{time:createdDateTime, errorCode:status.errorCode, failureReason:status.failureReason, resource:resourceDisplayName}" \
  --output table
```

Expected: `ErrorCode: 0` (success) for "Windows Azure Active Directory" resource.

### Common Sign-in Errors

| Error Code | Meaning | Resolution |
|---|---|---|
| 90094 | Admin consent is required | Complete Step 3 |
| 65001 | User/admin has not consented | Complete Step 3 (transitional, may appear briefly) |
| 0 | Success | No action needed |

---

## Step 6: Verify DevOps Agent Can Access Azure Resources

Run a test investigation in the DevOps Agent web app targeting an Azure resource in the registered subscription. Example:

> "Investigate Azure VM [vm-name] in subscription 167f5b70-5c4c-4e39-a0e9-2a7e43f42579"

The agent should be able to read:
- Azure VM details (power state, SKU, OS)
- Azure Activity Logs (who did what, when)
- Network configuration (NICs, NSGs, public IPs)
- Extensions and other resource metadata

---

## Summary of Configuration

| Component | Status | Details |
|---|---|---|
| Enterprise App (Service Principal) | ✅ Created | Auto-created during registration on 2026-04-06 |
| Admin Consent (Delegated Permission) | ✅ Granted | `user_impersonation` on Azure Resource Manager |
| RBAC Role Assignment | ✅ Reader | Subscription-level Reader on `167f5b70-...`, created 2026-04-07 |
| Authentication | ✅ Working | Sign-in succeeds (error code 0) |
| Investigation Access | ✅ Working | Successfully ran RCA on Azure VMs (Demo05, 2026-04-10) |

---

## Known Issue

The Azure subscription capability status shows **"—"** in the AWS DevOps Agent console instead of **"Valid"**, even though the agent can successfully authenticate and perform investigations against Azure resources. This has been reported to AWS support as a potential bug in the capability status validation logic.

**Evidence:** The agent completed a full RCA (Demo05) on Azure VM `testvmformurthy` on 2026-04-10, reading VM state, Activity Logs, Network config, and Extensions — confirming full read access to the subscription.

---

## Troubleshooting

### Check admin consent status
```bash
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/50f9cddd-f0f3-4a30-9741-a0203abbad7a/oauth2PermissionGrants" \
  --output json
```

### Check RBAC role assignment
```bash
az role assignment list \
  --subscription "167f5b70-5c4c-4e39-a0e9-2a7e43f42579" \
  --assignee "44659a95-bb9b-4119-ac67-65d547605eb2" \
  --output table
```

### Check recent sign-in attempts
```bash
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/auditLogs/signIns?\$filter=appId eq '44659a95-bb9b-4119-ac67-65d547605eb2'&\$top=5&\$orderby=createdDateTime desc" \
  --query "value[].{time:createdDateTime, errorCode:status.errorCode, failureReason:status.failureReason}" \
  --output table
```

### Check CloudWatch logs (AWS side)
```bash
aws logs filter-log-events \
  --profile zayo-ct --region us-east-1 \
  --log-group-name "/aws/vendedlogs/aidevops/service/APPLICATION_LOGS/414351351247" \
  --start-time $(date -u -v-24H +%s000) \
  --limit 50 --output json
```

---

*Document created: 2026-04-10*
*Author: Linga Murthy Allam*
