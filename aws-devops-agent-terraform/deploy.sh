#!/bin/bash

# AWS DevOps Agent Terraform Deployment Script

set -e

echo "🚀 AWS DevOps Agent Terraform Deployment"
echo "========================================"

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install Terraform first."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Check region
CURRENT_REGION=$(aws configure get region)
if [ "$CURRENT_REGION" != "us-east-1" ]; then
    echo "⚠️  Warning: Current AWS region is $CURRENT_REGION"
    echo "   AWS DevOps Agent requires us-east-1 region."
    echo "   You can override this in terraform.tfvars"
fi

echo "✅ Prerequisites check passed"

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    echo "📝 Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "✅ Please edit terraform.tfvars with your specific configuration"
    echo "   Then run this script again."
    exit 0
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "🔍 Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo ""
read -p "🤔 Do you want to apply this plan? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    rm -f tfplan
    exit 0
fi

# Apply deployment
echo "🚀 Applying deployment..."
echo "   Note: IAM roles may take time to propagate. If you see STS role errors, wait a moment and retry."

# Try to apply, with retry logic for IAM propagation issues
RETRY_COUNT=0
MAX_RETRIES=3

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if terraform apply tfplan; then
        echo "✅ Deployment successful!"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "⚠️  Deployment failed (attempt $RETRY_COUNT/$MAX_RETRIES)"
            echo "   This might be due to IAM propagation delays. Waiting 30 seconds before retry..."
            sleep 30
            echo "🔄 Retrying deployment..."
        else
            echo "❌ Deployment failed after $MAX_RETRIES attempts"
            echo "   Please check the errors above and try running 'terraform apply' manually"
            rm -f tfplan
            exit 1
        fi
    fi
done

# Clean up plan file
rm -f tfplan

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 IMPORTANT: Run the post-deployment script to complete setup:"
echo "   ./post-deploy.sh"
echo ""
echo "This will:"
echo "• Set up the AWS DevOps Agent CLI (if not already configured)"
echo "• Enable the Operator App (optional)"
echo "• Provide verification commands"
echo ""
echo "📋 Additional next steps:"
echo "1. Check the outputs above for your Agent Space ID"
echo "2. Visit https://console.aws.amazon.com/devopsagent/ to access the console"
echo "3. For external accounts, follow the cross-account setup instructions in README.md"