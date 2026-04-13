#!/bin/bash

# Post-deployment script for AWS DevOps Agent
# Handles manual steps that can't be done via Terraform

set -e

echo "🔧 AWS DevOps Agent Post-Deployment Setup"
echo "========================================="

# Check if AWS DevOps Agent CLI is configured
#echo "� Checkning AWS DevOps Agent CLI setup..."
echo "🔍 Checking AWS DevOps Agent CLI setup..."

if ! aws devopsagent help &>/dev/null; then
    echo "⚠️  AWS DevOps Agent CLI not configured. Setting it up now..."
    
    # Download the service model
    echo "📥 Downloading AWS DevOps Agent service model..."
    if ! curl -s -o devopsagent.json "https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json"; then
        echo "❌ Failed to download service model"
        echo "   Please download manually from: https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json"
        exit 1
    fi
    
    # Add the service model to AWS CLI
    echo "🔧 Adding DevOps Agent service to AWS CLI..."
    if ! aws configure add-model --service-model "file://${PWD}/devopsagent.json" --service-name devopsagent; then
        echo "❌ Failed to add service model to AWS CLI"
        echo "   Please run manually: aws configure add-model --service-model \"file://\${PWD}/devopsagent.json\" --service-name devopsagent"
        exit 1
    fi
    
    # Test the installation
    echo "🧪 Testing DevOps Agent CLI installation..."
    if aws devopsagent help &>/dev/null; then
        echo "✅ AWS DevOps Agent CLI configured successfully!"
    else
        echo "❌ DevOps Agent CLI test failed"
        echo "   Please verify the installation manually"
        exit 1
    fi
    
    # Clean up downloaded file
    rm -f devopsagent.json
else
    echo "✅ AWS DevOps Agent CLI already configured"
fi

# Get outputs from Terraform
echo ""
echo "📋 Getting Terraform outputs..."

AGENT_SPACE_ID=$(terraform output -raw agent_space_id 2>/dev/null || echo "")
OPERATOR_ROLE_ARN=$(terraform output -raw operator_app_role_arn 2>/dev/null || echo "")
AUTH_FLOW=$(terraform output -raw auth_flow 2>/dev/null || echo "iam")

if [ -z "$AGENT_SPACE_ID" ]; then
    echo "❌ Could not get Agent Space ID from Terraform outputs"
    echo "   Make sure Terraform has been applied successfully"
    exit 1
fi

echo "✅ Agent Space ID: $AGENT_SPACE_ID"
echo "✅ Operator Role ARN: $OPERATOR_ROLE_ARN"

# Check if operator app should be enabled
echo ""
read -p "🤔 Do you want to enable the Operator App? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Enabling Operator App..."
    
    aws devopsagent enable-operator-app \
        --agent-space-id "$AGENT_SPACE_ID" \
        --auth-flow "$AUTH_FLOW" \
        --operator-app-role-arn "$OPERATOR_ROLE_ARN" \
        --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
        --region us-east-1
    
    if [ $? -eq 0 ]; then
        echo "✅ Operator App enabled successfully!"
    else
        echo "❌ Failed to enable Operator App"
        echo "   You can try again manually with:"
        echo "   aws devopsagent enable-operator-app --agent-space-id $AGENT_SPACE_ID --auth-flow $AUTH_FLOW --operator-app-role-arn $OPERATOR_ROLE_ARN --endpoint-url 'https://api.prod.cp.aidevops.us-east-1.api.aws' --region us-east-1"
    fi
else
    echo "⏭️  Skipping Operator App setup"
fi

echo ""
echo "🎉 Post-deployment setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Visit https://console.aws.amazon.com/devopsagent/ to access the console"
echo "2. For external accounts, follow the cross-account setup in README.md"
echo ""
echo "🔍 Verify your setup:"
echo "aws devopsagent list-agent-spaces --endpoint-url 'https://api.prod.cp.aidevops.us-east-1.api.aws' --region us-east-1"
echo ""
echo "💡 Tip: The devopsagent.json service model has been added to your AWS CLI configuration."
echo "   If you need to set it up on other machines, download from:"
echo "   https://d1co8nkiwcta1g.cloudfront.net/devopsagent.json"