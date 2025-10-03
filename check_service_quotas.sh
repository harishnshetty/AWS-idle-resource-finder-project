#!/bin/bash
# check_service_quotas.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
UTILIZATION_THRESHOLD=80.0 # Percentage

echo "🔍 Checking AWS service quotas and limits in $REGION"

TOTAL_QUOTAS=0
NEAR_LIMIT_QUOTAS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Common services to check
SERVICES=("ec2" "rds" "elasticloadbalancing" "lambda" "s3")

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "🏷️ Service: $SERVICE"
    
    if QUOTAS=$(aws service-quotas list-service-quotas \
        --service-code "$SERVICE" \
        --region "$REGION" \
        --query 'Quotas[?Status==`AVAILABLE`]' \
        --output json 2>/dev/null); then
        
        QUOTA_COUNT=$(echo "$QUOTAS" | jq -r 'length')
        echo "   Available quotas: $QUOTA_COUNT"
        
        echo "$QUOTAS" | jq -c '.[]' | while read -r QUOTA; do
            TOTAL_QUOTAS=$((TOTAL_QUOTAS + 1))
            QUOTA_NAME=$(echo "$QUOTA" | jq -r '.QuotaName')
            QUOTA_VALUE=$(echo "$QUOTA" | jq -r '.Value')
            QUOTA_CODE=$(echo "$QUOTA" | jq -r '.QuotaCode')
            
            # Get current usage
            if USAGE=$(aws service-quotas get-aws-default-service-quota \
                --service-code "$SERVICE" \
                --quota-code "$QUOTA_CODE" \
                --region "$REGION" \
                --query 'Quota.Value' \
                --output text 2>/dev/null); then
                
                if [ -n "$USAGE" ] && [ "$USAGE" != "None" ] && [ "$QUOTA_VALUE" -gt 0 ]; then
                    USAGE_PERCENT=$(echo "scale=2; ($USAGE / $QUOTA_VALUE) * 100" | bc)
                    
                    if [ "$(echo "$USAGE_PERCENT > $UTILIZATION_THRESHOLD" | bc)" -eq 1 ]; then
                        echo "   ⚠️  $QUOTA_NAME: ${USAGE_PERCENT}% used (${USAGE}/${QUOTA_VALUE})"
                        NEAR_LIMIT_QUOTAS=$((NEAR_LIMIT_QUOTAS + 1))
                    else
                        echo "   ✅ $QUOTA_NAME: ${USAGE_PERCENT}% used"
                    fi
                fi
            else
                echo "   ℹ️  $QUOTA_NAME: Limit ${QUOTA_VALUE} (usage data unavailable)"
            fi
        done
    else
        echo "   ℹ️  No quota information available or no permissions"
    fi
done

# Check specific important quotas
echo ""
echo "🎯 Key Service Limits:"

# EC2 Instance limits
if EC2_LIMITS=$(aws ec2 describe-account-attributes \
    --attribute-names max-instances \
    --region "$REGION" \
    --query 'AccountAttributes[].AttributeValues[].AttributeValue' \
    --output text 2>/dev/null); then
    
    echo "  - EC2 Max Instances: $EC2_LIMITS"
fi

# EIP limits
if EIP_LIMITS=$(aws ec2 describe-account-attributes \
    --attribute-names max-elastic-ips \
    --region "$REGION" \
    --query 'AccountAttributes[].AttributeValues[].AttributeValue' \
    --output text 2>/dev/null); then
    
    echo "  - Elastic IPs: $EIP_LIMITS"
fi

echo ""
echo "📈 Summary:"
echo "   Total quotas checked: $TOTAL_QUOTAS"
echo "   Quotas near limit: $NEAR_LIMIT_QUOTAS"

if [ "$NEAR_LIMIT_QUOTAS" -gt 0 ]; then
    echo "⚠️  Recommendation: Consider requesting quota increases for near-limit services"
fi