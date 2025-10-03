#!/bin/bash
# check_kms_orphaned_keys.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "🔍 Checking for orphaned KMS keys in $REGION"

TOTAL_KEYS=0
ORPHANED_KEYS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# List all KMS keys
if ! KEYS=$(aws kms list-keys --region "$REGION" --query 'Keys[].KeyId' --output text 2>/dev/null); then
    echo "❌ No permission to list KMS keys"
    exit 0
fi

if [ -z "$KEYS" ] || [ "$KEYS" == "None" ]; then
    echo "✅ No KMS keys found in region $REGION"
    exit 0
fi

for KEY_ID in $KEYS; do
    TOTAL_KEYS=$((TOTAL_KEYS + 1))
    
    # Get key details
    if KEY_DETAILS=$(aws kms describe-key --key-id "$KEY_ID" --region "$REGION" 2>/dev/null); then
        KEY_MANAGER=$(echo "$KEY_DETAILS" | jq -r '.KeyMetadata.KeyManager')
        KEY_STATE=$(echo "$KEY_DETAILS" | jq -r '.KeyMetadata.KeyState')
        DESCRIPTION=$(echo "$KEY_DETAILS" | jq -r '.KeyMetadata.Description')
        
        echo ""
        echo "🔑 Key: $KEY_ID"
        echo "   State: $KEY_STATE"
        echo "   Manager: $KEY_MANAGER"
        echo "   Description: $DESCRIPTION"
        
        # Check if key is used (simplified check)
        if [ "$KEY_STATE" == "Enabled" ]; then
            # Check key usage in last 90 days
            if USAGE=$(aws cloudwatch get-metric-statistics \
                --namespace AWS/KMS \
                --metric-name KeyUsage \
                --dimensions Name=KeyId,Value="$KEY_ID" \
                --start-time "$(date -d '90 days ago' --iso-8601=seconds)" \
                --end-time "$(date --iso-8601=seconds)" \
                --period 2592000 \
                --statistics Sum \
                --region "$REGION" 2>/dev/null); then
                
                USAGE_COUNT=$(echo "$USAGE" | jq -r '.Datapoints[0].Sum // 0')
                
                if [ "$USAGE_COUNT" -eq 0 ]; then
                    echo "   ⚠️  ORPHANED: No usage in last 90 days"
                    ORPHANED_KEYS=$((ORPHANED_KEYS + 1))
                else
                    echo "   ✅ Active: $USAGE_COUNT uses in 90 days"
                fi
            else
                echo "   ℹ️  Usage data unavailable"
            fi
        else
            echo "   ℹ️  Key not enabled"
        fi
    else
        echo "   ❌ Unable to get key details"
    fi
done

echo ""
echo "📈 Summary:"
echo "   Total KMS keys: $TOTAL_KEYS"
echo "   Orphaned keys: $ORPHANED_KEYS"

if [ "$ORPHANED_KEYS" -gt 0 ]; then
    echo "⚠️  Recommendation: Consider disabling or deleting unused KMS keys"
fi