# Helper Script to Generate Terraform external_accounts Configuration
# Created by murthy on 02/02/2026

# This script helps you generate the external_accounts configuration for terraform.tfvars
# after deploying the StackSet to all target accounts

# Usage:
# 1. Create a file called target-accounts.txt with one account ID per line
# 2. Run: bash generate-external-accounts.sh > external-accounts-config.txt
# 3. Copy the output into your terraform.tfvars

#!/bin/bash

# Input file with account IDs (one per line)
ACCOUNTS_FILE="${1:-target-accounts.txt}"

# Default assume role name (change if different)
ASSUME_ROLE_NAME="${2:-OrganizationAccountAccessRole}"

if [ ! -f "$ACCOUNTS_FILE" ]; then
    echo "Error: File $ACCOUNTS_FILE not found!"
    echo ""
    echo "Usage: $0 [accounts-file] [assume-role-name]"
    echo ""
    echo "Create a file with account IDs (one per line):"
    echo "  608649261817"
    echo "  123456789012"
    echo "  234567890123"
    echo ""
    exit 1
fi

echo "# Generated external_accounts configuration"
echo "# Created by murthy on $(date +%Y-%m-%d)"
echo "# Add this to your terraform.tfvars file"
echo ""
echo "external_accounts = {"

while IFS= read -r account_id || [ -n "$account_id" ]; do
    # Skip empty lines and comments
    [[ -z "$account_id" || "$account_id" =~ ^[[:space:]]*# ]] && continue
    
    # Remove whitespace
    account_id=$(echo "$account_id" | tr -d '[:space:]')
    
    # Validate account ID format
    if [[ ! "$account_id" =~ ^[0-9]{12}$ ]]; then
        echo "  # WARNING: Invalid account ID: $account_id" >&2
        continue
    fi
    
    echo "  \"$account_id\" = {"
    echo "    account_id = \"$account_id\""
    echo "    role_arn   = \"arn:aws:iam::${account_id}:role/${ASSUME_ROLE_NAME}\""
    echo "  }"
done < "$ACCOUNTS_FILE"

echo "}"
echo ""
echo "# Total accounts: $(grep -v '^[[:space:]]*#' "$ACCOUNTS_FILE" | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')"
