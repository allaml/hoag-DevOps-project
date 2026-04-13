#!/bin/bash

# Test ServiceNow API connectivity from AWS
# This script verifies OAuth authentication and write permissions

# Configuration - UPDATE THESE VALUES
SNOW_INSTANCE="your-instance.service-now.com"
CLIENT_ID="your-client-id"
CLIENT_SECRET="your-client-secret"
USERNAME="your-username"
PASSWORD="your-password"
TEST_INCIDENT_NUMBER="INC0010001"  # Use an existing test incident

echo "=== ServiceNow API Connectivity Test ==="
echo ""

# Step 1: Get OAuth Token
echo "[1/3] Requesting OAuth token..."
TOKEN_RESPONSE=$(curl -s -X POST "https://${SNOW_INSTANCE}/oauth_token.do" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get OAuth token"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo "✅ OAuth token obtained"
echo ""

# Step 2: Test READ access
echo "[2/3] Testing READ access..."
READ_RESPONSE=$(curl -s -X GET "https://${SNOW_INSTANCE}/api/now/table/incident?sysparm_query=number=${TEST_INCIDENT_NUMBER}&sysparm_limit=1" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

INCIDENT_SYS_ID=$(echo $READ_RESPONSE | jq -r '.result[0].sys_id')

if [ "$INCIDENT_SYS_ID" == "null" ] || [ -z "$INCIDENT_SYS_ID" ]; then
    echo "❌ Failed to read incident"
    echo "Response: $READ_RESPONSE"
    exit 1
fi

echo "✅ READ access confirmed - Incident sys_id: ${INCIDENT_SYS_ID}"
echo ""

# Step 3: Test WRITE access
echo "[3/3] Testing WRITE access..."
WRITE_RESPONSE=$(curl -s -X PATCH "https://${SNOW_INSTANCE}/api/now/table/incident/${INCIDENT_SYS_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "work_notes": "DevOps Agent connectivity test - '"$(date)"'"
  }')

WRITE_STATUS=$(echo $WRITE_RESPONSE | jq -r '.result.sys_id')

if [ "$WRITE_STATUS" == "null" ] || [ -z "$WRITE_STATUS" ]; then
    echo "❌ Failed to write to incident"
    echo "Response: $WRITE_RESPONSE"
    echo ""
    echo "⚠️  This confirms the write-back issue!"
    echo "Action required: Uncheck 'Allow access only to APIs in selected scope' in ServiceNow"
    exit 1
fi

echo "✅ WRITE access confirmed - Work note added successfully"
echo ""
echo "=== All Tests Passed ==="
echo "ServiceNow API connectivity is working correctly."
