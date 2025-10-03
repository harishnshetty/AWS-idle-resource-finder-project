#!/bin/bash
# check_emr_idle_clusters.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "🔍 Checking for idle/running EMR clusters in $REGION"

TOTAL_CLUSTERS=0
RUNNING_CLUSTERS=0
IDLE_CLUSTERS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# List EMR clusters (all states)
if ! CLUSTERS=$(aws emr list-clusters --region "$REGION" --query 'Clusters[]' --output json 2>/dev/null); then
    echo "❌ No permission to list EMR clusters"
    exit 0
fi

if [ -z "$CLUSTERS" ] || [ "$CLUSTERS" == "null" ]; then
    echo "✅ No EMR clusters found in region $REGION"
    exit 0
fi

echo "$CLUSTERS" | jq -c '.[]' | while read -r CLUSTER; do
    TOTAL_CLUSTERS=$((TOTAL_CLUSTERS + 1))
    CLUSTER_ID=$(echo "$CLUSTER" | jq -r '.Id')
    CLUSTER_NAME=$(echo "$CLUSTER" | jq -r '.Name')
    STATE=$(echo "$CLUSTER" | jq -r '.Status.State')
    CREATED=$(echo "$CLUSTER" | jq -r '.Status.Timeline.CreationDateTime')
    
    echo "🔧 Cluster: $CLUSTER_NAME ($CLUSTER_ID)"
    echo "   State: $STATE, Created: $CREATED"
    
    if [ "$STATE" == "RUNNING" ] || [ "$STATE" == "WAITING" ]; then
        RUNNING_CLUSTERS=$((RUNNING_CLUSTERS + 1))
        
        # Check if cluster has been running for too long without activity
        CREATED_TS=$(date -d "$CREATED" +%s 2>/dev/null || echo 0)
        CURRENT_TS=$(date +%s)
        HOURS_RUNNING=$(( (CURRENT_TS - CREATED_TS) / 3600 ))
        
        echo "   ⏰ Running for: $HOURS_RUNNING hours"
        
        # Check for steps (simplified idle detection)
        if STEPS=$(aws emr list-steps --cluster-id "$CLUSTER_ID" --region "$REGION" --query 'Steps[].Status.State' --output text 2>/dev/null); then
            ACTIVE_STEPS=$(echo "$STEPS" | grep -c "RUNNING\|PENDING" || true)
            
            if [ "$ACTIVE_STEPS" -eq 0 ] && [ "$HOURS_RUNNING" -gt 2 ]; then
                echo "   ⚠️  IDLE: No active steps but cluster is running"
                IDLE_CLUSTERS=$((IDLE_CLUSTERS + 1))
            else
                echo "   ✅ Active: $ACTIVE_STEPS step(s) in progress"
            fi
        else
            echo "   ℹ️  Unable to check steps"
        fi
    else
        echo "   ℹ️  Cluster not running (state: $STATE)"
    fi
    echo ""
done

echo "📈 Summary:"
echo "   Total EMR clusters: $TOTAL_CLUSTERS"
echo "   Running clusters: $RUNNING_CLUSTERS"
echo "   Potentially idle clusters: $IDLE_CLUSTERS"

if [ "$IDLE_CLUSTERS" -gt 0 ]; then
    echo "⚠️  Recommendation: Terminate idle EMR clusters to avoid unnecessary costs"
fi