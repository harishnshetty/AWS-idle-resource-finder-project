#!/bin/bash
# check_idle_lambda.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
DAYS_THRESHOLD=30

echo "🔍 Checking for idle Lambda functions in $REGION (>$DAYS_THRESHOLD days)"

TOTAL_FUNCTIONS=0
IDLE_FUNCTIONS=0

# Get current timestamp in seconds
CURRENT_TS=$(date +%s)
DAYS_IN_SECONDS=$((DAYS_THRESHOLD * 24 * 60 * 60))

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Get list of Lambda functions
if ! FUNCTIONS=$(aws lambda list-functions --region "$REGION" --query 'Functions[].FunctionName' --output text 2>/dev/null); then
    echo "❌ No permission to list Lambda functions or no functions found"
    exit 0
fi

if [ -z "$FUNCTIONS" ] || [ "$FUNCTIONS" == "None" ]; then
    echo "✅ No Lambda functions found in region $REGION"
    exit 0
fi

echo "📊 Found Lambda functions:"
for FUNCTION in $FUNCTIONS; do
    TOTAL_FUNCTIONS=$((TOTAL_FUNCTIONS + 1))
    echo "  - $FUNCTION"
    
    # Get function metrics (simplified check)
    if METRICS=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Invocations \
        --dimensions Name=FunctionName,Value="$FUNCTION" \
        --start-time "$(date -d "$DAYS_THRESHOLD days ago" --iso-8601=seconds)" \
        --end-time "$(date --iso-8601=seconds)" \
        --period 2592000 \
        --statistics Sum \
        --region "$REGION" 2>/dev/null); then
        
        INVOCATIONS=$(echo "$METRICS" | jq -r '.Datapoints[0].Sum // 0')
        
        if [ "$INVOCATIONS" -eq 0 ]; then
            echo "    ⚠️  IDLE: No invocations in last $DAYS_THRESHOLD days"
            IDLE_FUNCTIONS=$((IDLE_FUNCTIONS + 1))
        else
            echo "    ✅ Active: $INVOCATIONS invocations"
        fi
    else
        echo "    ℹ️  Could not retrieve metrics"
    fi
done

echo ""
echo "📈 Summary:"
echo "   Total functions: $TOTAL_FUNCTIONS"
echo "   Idle functions: $IDLE_FUNCTIONS"

if [ "$IDLE_FUNCTIONS" -gt 0 ]; then
    echo "⚠️  Recommendation: Consider removing or archiving idle Lambda functions to reduce costs"
fi