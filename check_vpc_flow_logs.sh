#!/bin/bash
# check_vpc_flow_logs.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "🔍 Checking VPC Flow Logs configuration in $REGION"

TOTAL_VPCS=0
VPC_WITH_LOGS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# List all VPCs
if ! VPCS=$(aws ec2 describe-vpcs --region "$REGION" --query 'Vpcs[].VpcId' --output text 2>/dev/null); then
    echo "❌ No permission to describe VPCs"
    exit 0
fi

if [ -z "$VPCS" ] || [ "$VPCS" == "None" ]; then
    echo "✅ No VPCs found in region $REGION"
    exit 0
fi

for VPC_ID in $VPCS; do
    TOTAL_VPCS=$((TOTAL_VPCS + 1))
    
    # Check if flow logs are enabled
    if FLOW_LOGS=$(aws ec2 describe-flow-logs \
        --filter "Name=resource-id,Values=$VPC_ID" \
        --region "$REGION" \
        --query 'FlowLogs[0].FlowLogStatus' \
        --output text 2>/dev/null); then
        
        if [ "$FLOW_LOGS" == "ACTIVE" ] || [ "$FLOW_LOGS" == "ACTIVE " ]; then
            echo "✅ VPC $VPC_ID: Flow logs enabled"
            VPC_WITH_LOGS=$((VPC_WITH_LOGS + 1))
        else
            echo "⚠️  VPC $VPC_ID: No flow logs configured"
        fi
    else
        echo "❌ VPC $VPC_ID: Unable to check flow logs"
    fi
done

echo ""
echo "📈 Summary:"
echo "   Total VPCs: $TOTAL_VPCS"
echo "   VPCs with flow logs: $VPC_WITH_LOGS"
echo "   VPCs without flow logs: $((TOTAL_VPCS - VPC_WITH_LOGS))"

if [ "$VPC_WITH_LOGS" -lt "$TOTAL_VPCS" ]; then
    echo "⚠️  Recommendation: Enable VPC Flow Logs for security monitoring and troubleshooting"
fi