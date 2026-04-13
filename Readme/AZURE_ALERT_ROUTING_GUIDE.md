# Azure Alert Routing to AWS DevOps Agent - Next Sprint Guide
## Created by murthy on 04/05/2026

## Overview

After completing the Azure integration (see [AZURE_INTEGRATION_GUIDE.md](./AZURE_INTEGRATION_GUIDE.md)), the DevOps Agent can **investigate** Azure resources — but it won't automatically **detect** Azure alerts. This guide covers two approaches to route Azure alerts into DevOps Agent for automatic investigation.

**Sprint Goal:** Enable automatic Azure alert → DevOps Agent investigation flow  
**Agent Space:** ZayodevopsAgentSpace  
**AWS Region:** us-east-1

> **Reference Docs:**
> - [Invoking DevOps Agent through Webhook](https://docs.aws.amazon.com/devopsagent/latest/userguide/configuring-capabilities-for-aws-devops-agent-invoking-devops-agent-through-webhook.html)
> - [EventBridge Integration](https://docs.aws.amazon.com/devopsagent/latest/userguide/configuring-capabilities-for-aws-devops-agent-integrating-devops-agent-into-event-driven-applications-using-amazon-eventbridge-index.html)

---

## How Your Current SNOW Integration Works

Your existing setup uses SNOW as a **ticketing system** — not a webhook trigger:

```
Incident happens
    → SNOW incident created (manually or from alert source)
        → DevOps Agent reads the SNOW incident
            → Agent investigates
                → Agent writes findings back to SNOW (via EventBridge → Lambda → VPC Endpoint → SNOW)
```

There is **no webhook** from SNOW pushing alerts to DevOps Agent. The agent connects to SNOW to read incidents and write back results. This means to get Azure alerts flowing, you need to get them **into SNOW as incidents** — the agent will pick them up from there.

---

## Approach Options

| Approach | Flow | Best For |
|----------|------|----------|
| **Option A** | Azure Monitor → SNOW incident → DevOps Agent reads it | Keeps SNOW as single pane of glass; builds on existing setup |
| **Option B** | Azure Monitor → Generic Webhook → DevOps Agent directly | Faster trigger; bypasses SNOW; good for alerts that don't need a ticket |

---

## Option A: Azure Monitor → ServiceNow (Recommended)

> Since DevOps Agent already reads SNOW incidents, you just need to get Azure alerts into SNOW. The agent will pick them up automatically.

### Prerequisites

- [ ] Azure Monitor access
- [ ] ServiceNow instance access (admin or ITSM admin)
- [ ] One of: SNOW ITSM connector, Azure Logic App, or SNOW Event Management

### Phase 1: Choose Your Azure → SNOW Method

There are three ways to get Azure alerts into SNOW. Pick the one that fits your environment:

#### Method A: ServiceNow Azure Monitoring Connector (Simplest)

> 📍 **Where:** ServiceNow Admin Portal

ServiceNow has a built-in Azure monitoring integration.

1. In ServiceNow → **System Applications** → search for **Azure** or **Cloud Management**
2. Install/enable the **Azure Monitoring** integration if not already present
3. Configure the connector:
   - Provide your Azure tenant ID and subscription ID
   - Authenticate via service principal or managed identity
   - Map Azure alert severities to SNOW incident priorities:
     - Sev0 → P1 (Critical)
     - Sev1 → P2 (High)
     - Sev2 → P3 (Medium)
     - Sev3/Sev4 → P4 (Low)
4. Enable auto-creation of incidents from Azure alerts

#### Method B: Azure Monitor Action Group → SNOW Webhook

> 📍 **Where:** Azure Portal + ServiceNow

1. **In ServiceNow** — create an inbound REST API or Scripted REST API:
   - Navigate to **System Web Services** → **Scripted REST APIs** → **New**
   - Name: `Azure Monitor Alerts`
   - Create a POST resource that creates incidents from the Azure alert payload
   - Note the endpoint URL: `https://<YOUR-INSTANCE>.service-now.com/api/<scope>/azure_alerts`

2. **In Azure Portal** — create an Action Group:
   - Azure Portal → **Monitor** → **Alerts** → **Action groups** → **+ Create**
   - Name: `SNOW-Incident-ActionGroup`
   - Actions tab → Action type: **Webhook**
   - URI: Your SNOW Scripted REST API endpoint
   - Configure authentication (Basic Auth or OAuth)

3. **Attach to alert rules:**
   - Azure Portal → **Monitor** → **Alerts** → **Alert rules**
   - Edit each rule → **Actions** → add `SNOW-Incident-ActionGroup`

#### Method C: Azure Logic App → SNOW (Most Flexible)

> 📍 **Where:** Azure Portal

1. Azure Portal → **Logic Apps** → **+ Add**
2. Name: `azure-alerts-to-snow`
3. Design the workflow:

   **Trigger:** When a HTTP request is received

   **Action 1:** Parse the Azure Monitor alert payload (common alert schema)

   **Action 2:** ServiceNow - Create Record
   - Connection: Your SNOW instance (Logic Apps has a built-in ServiceNow connector)
   - Table: `incident`
   - Field mapping:
     - Short description: `Alert rule name - Resource name`
     - Description: Alert details from payload
     - Urgency: Mapped from alert severity
     - Category: `Azure`
     - Assignment group: Your SRE/DevOps team

4. Copy the Logic App HTTP trigger URL
5. Create an Azure Monitor Action Group pointing to this Logic App (same as Method B step 2, but use **Logic App** action type instead of Webhook)

### Phase 1 Result (All Methods)

```
Azure Monitor Alert fires
    → SNOW incident created (via connector/webhook/Logic App)
        → DevOps Agent reads the SNOW incident (existing integration)
            → Agent investigates with Azure resource visibility
                → Agent writes findings back to SNOW
```

### Phase 2: Test the Flow (~5 minutes)

1. **Trigger a test alert:**
   - Azure Portal → **Monitor** → **Alerts** → pick an alert rule → **Test action group**
   - Or manually create a condition that triggers (e.g., scale a VM to spike CPU)

2. **Verify in SNOW:**
   - Check that a new incident was created
   - Verify the severity/priority mapping is correct
   - Confirm the description has enough context for the agent

3. **Verify DevOps Agent picks it up:**
   - In the DevOps Agent console → **ZayodevopsAgentSpace** → **Investigations**
   - The agent should start investigating the SNOW incident
   - Check that it accesses Azure resources during the investigation

---

## Option B: Azure Monitor → Generic Webhook → DevOps Agent (Direct)

> Bypasses SNOW entirely. Use this for alerts where you want fast investigation without creating a ticket first.

### Phase 1: Generate a Generic Webhook (~2 minutes)

> 📍 **Where:** AWS Management Console

1. Go to [AWS DevOps Agent console](https://console.aws.amazon.com/aidevops/)
2. Select **ZayodevopsAgentSpace**
3. Go to the **Capabilities** tab
4. In the **Webhook** section, click **Configure**
5. Click **Generate webhook**
6. **Save the HMAC key and secret securely** — you can't retrieve them again
7. Copy the **webhook endpoint URL**

> ⚠️ Generic webhooks use **HMAC authentication** (not bearer token).

### Phase 2: Create an Azure Function for HMAC Signing (~15 minutes)

> 📍 **Where:** Azure Portal

Azure Monitor can't generate HMAC signatures directly, so you need a small Azure Function as middleware.

#### Step 2.1: Create the Azure Function App

1. Azure Portal → **Function App** → **+ Create**
2. Runtime: **Node.js 20**
3. Plan: **Consumption (Serverless)**
4. Name: `devopsagent-webhook-forwarder`
5. Create

#### Step 2.2: Add the Function Code

Create a new HTTP trigger function with this code:

```javascript
const crypto = require('crypto');

module.exports = async function (context, req) {
    const webhookUrl = process.env.DEVOPS_AGENT_WEBHOOK_URL;
    const webhookSecret = process.env.DEVOPS_AGENT_WEBHOOK_SECRET;

    const essentials = req.body?.data?.essentials || {};

    const severityMap = {
        'Sev0': 'CRITICAL',
        'Sev1': 'HIGH',
        'Sev2': 'MEDIUM',
        'Sev3': 'LOW',
        'Sev4': 'LOW'
    };

    const timestamp = new Date().toISOString().replace(/\.\d{3}Z/, '.000Z');

    const payload = JSON.stringify({
        eventType: 'incident',
        incidentId: essentials.alertId || `azure-${Date.now()}`,
        action: 'created',
        priority: severityMap[essentials.severity] || 'MEDIUM',
        title: essentials.alertRule || 'Azure Monitor Alert',
        description: essentials.description || 'Alert triggered from Azure Monitor',
        timestamp: timestamp,
        service: essentials.targetResourceType || 'Azure',
        data: {
            metadata: {
                source: 'azure-monitor',
                subscriptionId: essentials.alertTargetIDs?.[0] || '',
                severity: essentials.severity || ''
            }
        }
    });

    const hmac = crypto.createHmac('sha256', webhookSecret);
    hmac.update(`${timestamp}:${payload}`, 'utf8');
    const signature = hmac.digest('base64');

    const response = await fetch(webhookUrl, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-amzn-event-timestamp': timestamp,
            'x-amzn-event-signature': signature
        },
        body: payload
    });

    context.res = {
        status: response.status,
        body: `Forwarded to DevOps Agent: ${response.status}`
    };
};
```

#### Step 2.3: Configure Environment Variables

1. Function App → **Configuration** → **Application settings**
2. Add:
   - `DEVOPS_AGENT_WEBHOOK_URL` = your webhook endpoint URL from Phase 1
   - `DEVOPS_AGENT_WEBHOOK_SECRET` = your HMAC secret from Phase 1

> ⚠️ For production, store the secret in **Azure Key Vault** and reference it via Key Vault reference.

#### Step 2.4: Get the Function URL

1. Go to your function → **Get Function URL**
2. Copy it — you'll use this in the Azure Monitor Action Group

### Phase 3: Connect Azure Monitor (~5 minutes)

> 📍 **Where:** Azure Portal

1. Azure Portal → **Monitor** → **Alerts** → **Action groups** → **+ Create**
2. Name: `DevOpsAgent-Direct-ActionGroup`
3. Actions tab:
   - Action type: **Azure Function**
   - Select `devopsagent-webhook-forwarder`
4. Save
5. Attach this action group to your Azure Monitor alert rules

### Phase 3 Result

```
Azure Monitor Alert fires
    → Action Group triggers Azure Function
        → Function formats payload + HMAC signs it
            → POST to DevOps Agent generic webhook
                → Agent investigates (with Azure resource visibility)
```

### Test with cURL

```bash
#!/bin/bash

WEBHOOK_URL="<YOUR-DEVOPS-AGENT-WEBHOOK-URL>"
SECRET="<YOUR-WEBHOOK-SECRET>"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
INCIDENT_ID="azure-test-$(date +%s)"

PAYLOAD=$(cat <<EOF
{
"eventType": "incident",
"incidentId": "$INCIDENT_ID",
"action": "created",
"priority": "HIGH",
"title": "Test Azure Alert - VM CPU High",
"description": "Test alert from Azure Monitor",
"service": "Microsoft.Compute/virtualMachines",
"timestamp": "$TIMESTAMP",
"data": {
  "metadata": {
    "source": "azure-monitor",
    "environment": "production"
  }
}
}
EOF
)

SIGNATURE=$(echo -n "${TIMESTAMP}:${PAYLOAD}" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "x-amzn-event-timestamp: $TIMESTAMP" \
  -H "x-amzn-event-signature: $SIGNATURE" \
  -d "$PAYLOAD"
```

---

## Recommendation

Start with **Option A** (Azure Monitor → SNOW → DevOps Agent) because:

1. Your DevOps Agent already reads SNOW incidents — no new AWS-side config needed
2. Keeps SNOW as the single source of truth for all incidents across AWS + Azure
3. No HMAC signing complexity
4. Your team already knows the SNOW workflow
5. You only need to configure the Azure → SNOW piece

Add Option B later if you need faster, direct investigations that skip ticketing.

---

## Quick Reference

| Component | Where | What |
|-----------|-------|------|
| Azure Monitor Alert Rules | 📍 **Azure Portal** → Monitor → Alerts | Define what triggers alerts |
| Action Groups | 📍 **Azure Portal** → Monitor → Action Groups | Route alerts to SNOW or Azure Function |
| SNOW Connector/Webhook | 📍 **ServiceNow** or **Azure Portal** | Bridge between Azure alerts and SNOW incidents |
| Generic Webhook (Option B) | 📍 **AWS Console** → DevOps Agent → Capabilities | Endpoint for direct alert ingestion |
| Azure Function (Option B) | 📍 **Azure Portal** → Function Apps | HMAC signing + forwarding |

---

## Next Steps

- [ ] Decide on Option A, Option B, or both
- [ ] For Option A: check with your SNOW admin which Azure→SNOW method is already available
- [ ] Identify which Azure alert rules to route first (start with critical/high severity)
- [ ] Test end-to-end flow with a non-production alert
- [ ] Consider [EventBridge integration](https://docs.aws.amazon.com/devopsagent/latest/userguide/configuring-capabilities-for-aws-devops-agent-integrating-devops-agent-into-event-driven-applications-using-amazon-eventbridge-index.html) for custom automation on investigation results
