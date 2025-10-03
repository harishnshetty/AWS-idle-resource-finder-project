#!/bin/bash
# check_redshift_utilization.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
CPU_THRESHOLD=30.0 # Percentage

echo "🔍 Checking Redshift cluster utilization in $REGION"

TOTAL_CLUSTERS=0
UNDERUTILIZED_CLUSTERS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# List Redshift clusters
if ! CLUSTERS=$(aws redshift describe-clusters --region "$REGION" --query 'Clusters[]' --output json 2>/dev/null); then
    echo "❌ No permission to describe Redshift clusters"
    exit 0
fi

if [ -z "$CLUSTERS" ] || [ "$CLUSTERS" == "null" ]; then
    echo "✅ No Redshift clusters found in region $REGION"
    exit 0
fi

echo "$CLUSTERS" | jq -c '.[]' | while read -r CLUSTER; do
    TOTAL_CLUSTERS=$((TOTAL_CLUSTERS + 1))
    CLUSTER_ID=$(echo "$CLUSTER" | jq -r '.ClusterIdentifier')
    NODE_TYPE=$(echo "$CLUSTER" | jq -r '.NodeType')
    NODES=$(echo "$CLUSTER" | jq -r '.NumberOfNodes')
    STATE=$(echo "$CLUSTER" | jq -r '.ClusterStatus')
    
    echo "🏗️ Cluster: $CLUSTER_ID"
    echo "   Type: $NODE_TYPE, Nodes: $NODES, State: $STATE"
    
    if [ "$STATE" == "available" ]; then
        # Check CPU utilization
        if CPU_UTILIZATION=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/Redshift \
            --metric-name CPUUtilization \
            --dimensions Name=ClusterIdentifier,Value="$CLUSTER_ID" \
            --start-time "$(date -d '7 days ago' --iso-8601=seconds)" \
            --end-time "$(date --iso-8601=seconds)" \
            --period 3600 \
            --statistics Average \
            --region "$REGION" 2>/dev/null); then
            
            AVG_CPU=$(echo "$CPU_UTILIZATION" | jq -r '[.Datapoints[].Average] | max // 0')
            
            if [ "$(echo "$AVG_CPU < $CPU_THRESHOLD" | bc)" -eq 1 ]; then
                echo "   ⚠️  UNDERUTILIZED: Peak CPU ${AVG_CPU}% (< ${CPU_THRESHOLD}%)"
                UNDERUTILIZED_CLUSTERS=$((UNDERUTILIZED_CLUSTERS + 1))
                
                # Check storage
                if STORAGE=$(aws cloudwatch get-metric-statistics \
                    --namespace AWS/Redshift \
                    --metric-name DatabaseConnections \
                    --dimensions Name=ClusterIdentifier,Value="$CLUSTER_ID" \
                    --start-time "$(date -d '7 days ago' --iso-8601=seconds)" \
                    --end-time "$(date --iso-8601=seconds)" \
                    --period 3600 \
                    --statistics Average \
                    --region "$REGION" 2>/dev/null); then
                    
                    AVG_CONNECTIONS=$(echo "$STORAGE" | jq -r '[.Datapoints[].Average] | max // 0')
                    echo "   📊 Max connections: $AVG_CONNECTIONS"
                fi
            else
                echo "   ✅ Utilized: Peak CPU ${AVG_CPU}%"
            fi
        else
            echo "   ℹ️  CPU metrics unavailable"
        fi
    else
        echo "   ℹ️  Cluster not in available state"
    fi
    echo ""
done

echo "📈 Summary:"
echo "   Total Redshift clusters: $TOTAL_CLUSTERS"
echo "   Underutilized clusters: $UNDERUTILIZED_CLUSTERS"

if [ "$UNDERUTILIZED_CLUSTERS" -gt 0 ]; then
    echo "⚠️  Recommendation: Consider downsizing or pausing underutilized Redshift clusters"
fi