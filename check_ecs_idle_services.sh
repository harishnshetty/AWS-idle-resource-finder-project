#!/bin/bash
# check_ecs_idle_services.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
CPU_THRESHOLD=5.0 # Percentage

echo "🔍 Checking for idle ECS services (CPU < ${CPU_THRESHOLD}%) in $REGION"

TOTAL_SERVICES=0
IDLE_SERVICES=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Get list of ECS clusters
if ! CLUSTERS=$(aws ecs list-clusters --region "$REGION" --query 'clusterArns' --output text 2>/dev/null); then
    echo "❌ No permission to list ECS clusters"
    exit 0
fi

if [ -z "$CLUSTERS" ] || [ "$CLUSTERS" == "None" ]; then
    echo "✅ No ECS clusters found in region $REGION"
    exit 0
fi

for CLUSTER_ARN in $CLUSTERS; do
    CLUSTER_NAME=$(echo "$CLUSTER_ARN" | awk -F'/' '{print $NF}')
    echo ""
    echo "🏗️ Cluster: $CLUSTER_NAME"
    
    # List services in cluster
    if SERVICES=$(aws ecs list-services --cluster "$CLUSTER_NAME" --region "$REGION" --query 'serviceArns' --output text 2>/dev/null); then
        for SERVICE_ARN in $SERVICES; do
            TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
            SERVICE_NAME=$(echo "$SERVICE_ARN" | awk -F'/' '{print $NF}')
            
            echo "  - Service: $SERVICE_NAME"
            
            # Get CPU utilization (simplified check)
            if CPU_UTILIZATION=$(aws cloudwatch get-metric-statistics \
                --namespace AWS/ECS \
                --metric-name CPUUtilization \
                --dimensions Name=ClusterName,Value="$CLUSTER_NAME" Name=ServiceName,Value="$SERVICE_NAME" \
                --start-time "$(date -d '7 days ago' --iso-8601=seconds)" \
                --end-time "$(date --iso-8601=seconds)" \
                --period 3600 \
                --statistics Average \
                --region "$REGION" 2>/dev/null); then
                
                AVG_CPU=$(echo "$CPU_UTILIZATION" | jq -r '.Datapoints[].Average' | head -1)
                
                if [ -n "$AVG_CPU" ] && [ "$(echo "$AVG_CPU < $CPU_THRESHOLD" | bc)" -eq 1 ]; then
                    echo "    ⚠️  IDLE: Average CPU ${AVG_CPU}% (< ${CPU_THRESHOLD}%)"
                    IDLE_SERVICES=$((IDLE_SERVICES + 1))
                else
                    echo "    ✅ Active: Average CPU ${AVG_CPU:-"N/A"}%"
                fi
            else
                echo "    ℹ️  CPU metrics unavailable"
            fi
        done
    fi
done

echo ""
echo "📈 Summary:"
echo "   Total ECS services: $TOTAL_SERVICES"
echo "   Idle services: $IDLE_SERVICES"

if [ "$IDLE_SERVICES" -gt 0 ]; then
    echo "⚠️  Recommendation: Consider scaling down or removing idle ECS services"
fi