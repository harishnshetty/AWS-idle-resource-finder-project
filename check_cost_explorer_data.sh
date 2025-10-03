#!/bin/bash
# check_cost_explorer_data.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "🔍 Analyzing AWS Cost Explorer data (last 30 days)"

TOTAL_COST=0
SERVICE_COUNT=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Check if we have cost explorer permissions
echo "💰 Cost Analysis (Last 30 Days):"

# Get cost by service
if COST_DATA=$(aws ce get-cost-and-usage \
    --time-period Start=$(date -d "30 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics "UnblendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[?Metrics.UnblendedCost.Amount > `0`]' \
    --output json 2>/dev/null); then
    
    echo "✅ Cost Explorer access available"
    echo ""
    echo "📊 Top Services by Cost:"
    
    # Sort by cost and get top 10
    echo "$COST_DATA" | jq -c 'sort_by(.Metrics.UnblendedCost.Amount | tonumber) | reverse[:10]' | jq -c '.[]' | while read -r SERVICE; do
        SERVICE_NAME=$(echo "$SERVICE" | jq -r '.Keys[0]')
        COST_AMOUNT=$(echo "$SERVICE" | jq -r '.Metrics.UnblendedCost.Amount')
        COST_CURRENCY=$(echo "$SERVICE" | jq -r '.Metrics.UnblendedCost.Unit')
        
        if [ "$(echo "$COST_AMOUNT > 0" | bc)" -eq 1 ]; then
            SERVICE_COUNT=$((SERVICE_COUNT + 1))
            TOTAL_COST=$(echo "$TOTAL_COST + $COST_AMOUNT" | bc)
            
            echo "  - $SERVICE_NAME: $COST_CURRENCY $COST_AMOUNT"
        fi
    done
    
    echo ""
    echo "📈 Summary:"
    echo "   Total services with cost: $SERVICE_COUNT"
    echo "   Total cost (last 30 days): $COST_CURRENCY $TOTAL_COST"
    
    # Get month-over-month change
    if PREVIOUS_COST=$(aws ce get-cost-and-usage \
        --time-period Start=$(date -d "60 days ago" +%Y-%m-%d),End=$(date -d "30 days ago" +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics "UnblendedCost" \
        --query 'ResultsByTime[0].Total.UnblendedCost' \
        --output json 2>/dev/null); then
        
        PREVIOUS_AMOUNT=$(echo "$PREVIOUS_COST" | jq -r '.Amount')
        CURRENT_AMOUNT=$TOTAL_COST
        
        if [ -n "$PREVIOUS_AMOUNT" ] && [ "$PREVIOUS_AMOUNT" != "null" ] && [ "$(echo "$PREVIOUS_AMOUNT > 0" | bc)" -eq 1 ]; then
            PERCENT_CHANGE=$(echo "scale=2; (($CURRENT_AMOUNT - $PREVIOUS_AMOUNT) / $PREVIOUS_AMOUNT) * 100" | bc)
            
            if [ "$(echo "$PERCENT_CHANGE > 0" | bc)" -eq 1 ]; then
                echo "   📈 Cost change: +$PERCENT_CHANGE% from previous period"
            else
                echo "   📉 Cost change: $PERCENT_CHANGE% from previous period"
            fi
        fi
    fi
    
else
    echo "❌ Cost Explorer access not available or no permissions"
    echo "ℹ️  Required IAM permissions: ce:GetCostAndUsage, ce:GetDimensionValues"
fi

# Check for cost anomalies (simplified)
echo ""
echo "🚨 Cost Anomaly Detection:"
echo "  ℹ️  For detailed anomaly detection, enable AWS Cost Anomaly Detection service"
echo "  💡 Monitor: EC2, RDS, Data Transfer, and S3 costs as common areas for optimization"