#!/bin/bash
# check_secrets_manager_old_secrets.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
DAYS_THRESHOLD=90

echo "🔍 Checking for old Secrets Manager secrets (>$DAYS_THRESHOLD days) in $REGION"

TOTAL_SECRETS=0
OLD_SECRETS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# List all secrets
if ! SECRETS=$(aws secretsmanager list-secrets --region "$REGION" --query 'SecretList[]' --output json 2>/dev/null); then
    echo "❌ No permission to list Secrets Manager secrets"
    exit 0
fi

if [ -z "$SECRETS" ] || [ "$SECRETS" == "null" ]; then
    echo "✅ No Secrets Manager secrets found in region $REGION"
    exit 0
fi

echo "$SECRETS" | jq -c '.[]' | while read -r SECRET; do
    TOTAL_SECRETS=$((TOTAL_SECRETS + 1))
    SECRET_NAME=$(echo "$SECRET" | jq -r '.Name')
    DESCRIPTION=$(echo "$SECRET" | jq -r '.Description // "No description"')
    LAST_ACCESSED=$(echo "$SECRET" | jq -r '.LastAccessedDate // .CreatedDate')
    CREATED_DATE=$(echo "$SECRET" | jq -r '.CreatedDate')
    
    echo "🔐 Secret: $SECRET_NAME"
    echo "   Description: $DESCRIPTION"
    echo "   Created: $CREATED_DATE"
    
    if [ "$LAST_ACCESSED" != "null" ]; then
        LAST_TS=$(date -d "$LAST_ACCESSED" +%s 2>/dev/null || echo 0)
        CURRENT_TS=$(date +%s)
        DAYS_SINCE_ACCESS=$(( (CURRENT_TS - LAST_TS) / 86400 ))
        
        echo "   Last accessed: $LAST_ACCESSED ($DAYS_SINCE_ACCESS days ago)"
        
        if [ "$DAYS_SINCE_ACCESS" -gt "$DAYS_THRESHOLD" ]; then
            echo "   ⚠️  OLD: Not accessed in $DAYS_SINCE_ACCESS days"
            OLD_SECRETS=$((OLD_SECRETS + 1))
        else
            echo "   ✅ Recently accessed"
        fi
    else
        echo "   ℹ️  No access history"
    fi
    
    # Check rotation status
    ROTATION_ENABLED=$(echo "$SECRET" | jq -r '.RotationEnabled')
    if [ "$ROTATION_ENABLED" == "true" ]; then
        echo "   ♻️  Rotation: Enabled"
    else
        echo "   ⏸️  Rotation: Disabled"
    fi
    echo ""
done

echo "📈 Summary:"
echo "   Total secrets: $TOTAL_SECRETS"
echo "   Old secrets: $OLD_SECRETS"

if [ "$OLD_SECRETS" -gt 0 ]; then
    echo "⚠️  Recommendation: Review and consider rotating or removing old secrets"
fi