#!/bin/bash
# check_sagemaker_idle_instances.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
HOURS_THRESHOLD=24

echo "🔍 Checking for idle SageMaker instances (>${HOURS_THRESHOLD} hours) in $REGION"

TOTAL_INSTANCES=0
IDLE_INSTANCES=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Check Notebook Instances
echo "📓 SageMaker Notebook Instances:"
if NOTEBOOKS=$(aws sagemaker list-notebook-instances --region "$REGION" --query 'NotebookInstances[]' --output json 2>/dev/null); then
    echo "$NOTEBOOKS" | jq -c '.[]' | while read -r NOTEBOOK; do
        TOTAL_INSTANCES=$((TOTAL_INSTANCES + 1))
        INSTANCE_NAME=$(echo "$NOTEBOOK" | jq -r '.NotebookInstanceName')
        STATUS=$(echo "$NOTEBOOK" | jq -r '.NotebookInstanceStatus')
        CREATION_TIME=$(echo "$NOTEBOOK" | jq -r '.CreationTime')
        LAST_MODIFIED=$(echo "$NOTEBOOK" | jq -r '.LastModifiedTime')
        INSTANCE_TYPE=$(echo "$NOTEBOOK" | jq -r '.InstanceType')
        
        echo "  - $INSTANCE_NAME ($INSTANCE_TYPE)"
        echo "    Status: $STATUS, Created: $CREATION_TIME"
        
        if [ "$STATUS" == "InService" ]; then
            # Check if instance has been running for a long time
            CREATED_TS=$(date -d "$CREATION_TIME" +%s 2>/dev/null || echo 0)
            CURRENT_TS=$(date +%s)
            HOURS_RUNNING=$(( (CURRENT_TS - CREATED_TS) / 3600 ))
            
            echo "    ⏰ Running for: $HOURS_RUNNING hours"
            
            if [ "$HOURS_RUNNING" -gt "$HOURS_THRESHOLD" ]; then
                echo "    ⚠️  IDLE: Consider stopping if not actively used"
                IDLE_INSTANCES=$((IDLE_INSTANCES + 1))
            else
                echo "    ✅ Recently started"
            fi
        else
            echo "    ℹ️  Instance not in service (status: $STATUS)"
        fi
    done
else
    echo "  ℹ️ No SageMaker notebook instances found or no permissions"
fi

# Check Training Jobs (long-running)
echo ""
echo "🏋️ SageMaker Training Jobs (recent):"
if TRAINING_JOBS=$(aws sagemaker list-training-jobs --region "$REGION" --max-results 10 --query 'TrainingJobSummaries[]' --output json 2>/dev/null); then
    echo "$TRAINING_JOBS" | jq -c '.[]' | while read -r JOB; do
        JOB_NAME=$(echo "$JOB" | jq -r '.TrainingJobName')
        STATUS=$(echo "$JOB" | jq -r '.TrainingJobStatus')
        CREATION_TIME=$(echo "$JOB" | jq -r '.CreationTime')
        
        echo "  - $JOB_NAME"
        echo "    Status: $STATUS, Created: $CREATION_TIME"
        
        if [ "$STATUS" == "InProgress" ]; then
            CREATED_TS=$(date -d "$CREATION_TIME" +%s 2>/dev/null || echo 0)
            CURRENT_TS=$(date +%s)
            HOURS_RUNNING=$(( (CURRENT_TS - CREATED_TS) / 3600 ))
            
            if [ "$HOURS_RUNNING" -gt 48 ]; then
                echo "    ⚠️  LONG_RUNNING: Training job running for $HOURS_RUNNING hours"
            fi
        fi
    done
fi

echo ""
echo "📈 Summary:"
echo "   Total SageMaker instances: $TOTAL_INSTANCES"
echo "   Potentially idle instances: $IDLE_INSTANCES"

if [ "$IDLE_INSTANCES" -gt 0 ]; then
    echo "⚠️  Recommendation: Stop SageMaker notebook instances when not in use to save costs"
fi