#!/bin/bash
# check_codepipeline_idle_pipelines.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
DAYS_THRESHOLD=60

echo "🔍 Checking for inactive CodePipeline pipelines (>$DAYS_THRESHOLD days) in $REGION"

TOTAL_PIPELINES=0
INACTIVE_PIPELINES=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# List CodePipeline pipelines
if ! PIPELINES=$(aws codepipeline list-pipelines --region "$REGION" --query 'pipelines[].name' --output text 2>/dev/null); then
    echo "❌ No permission to list CodePipeline pipelines"
    exit 0
fi

if [ -z "$PIPELINES" ] || [ "$PIPELINES" == "None" ]; then
    echo "✅ No CodePipeline pipelines found in region $REGION"
    exit 0
fi

for PIPELINE_NAME in $PIPELINES; do
    TOTAL_PIPELINES=$((TOTAL_PIPELINES + 1))
    
    echo "⚙️ Pipeline: $PIPELINE_NAME"
    
    # Get pipeline execution history
    if EXECUTIONS=$(aws codepipeline list-pipeline-executions \
        --pipeline-name "$PIPELINE_NAME" \
        --region "$REGION" \
        --query 'pipelineExecutionSummaries[0]' \
        --output json 2>/dev/null); then
        
        if [ -n "$EXECUTIONS" ] && [ "$EXECUTIONS" != "null" ]; then
            LAST_EXECUTION_TIME=$(echo "$EXECUTIONS" | jq -r '.lastUpdateTime')
            STATUS=$(echo "$EXECUTIONS" | jq -r '.status')
            
            if [ "$LAST_EXECUTION_TIME" != "null" ]; then
                LAST_TS=$(date -d "$LAST_EXECUTION_TIME" +%s 2>/dev/null || echo 0)
                CURRENT_TS=$(date +%s)
                DAYS_SINCE_EXECUTION=$(( (CURRENT_TS - LAST_TS) / 86400 ))
                
                echo "   Last execution: $LAST_EXECUTION_TIME ($DAYS_SINCE_EXECUTION days ago)"
                echo "   Status: $STATUS"
                
                if [ "$DAYS_SINCE_EXECUTION" -gt "$DAYS_THRESHOLD" ]; then
                    echo "   ⚠️  INACTIVE: No executions in $DAYS_SINCE_EXECUTION days"
                    INACTIVE_PIPELINES=$((INACTIVE_PIPELINES + 1))
                else
                    echo "   ✅ Recently active"
                fi
            else
                echo "   ℹ️  No execution history found"
                INACTIVE_PIPELINES=$((INACTIVE_PIPELINES + 1))
            fi
        else
            echo "   ℹ️  No executions found for pipeline"
            INACTIVE_PIPELINES=$((INACTIVE_PIPELINES + 1))
        fi
    else
        echo "   ❌ Unable to get execution history"
    fi
    
    # Get pipeline details
    if PIPELINE_DETAILS=$(aws codepipeline get-pipeline \
        --name "$PIPELINE_NAME" \
        --region "$REGION" \
        --query 'pipeline.stages[].name' \
        --output text 2>/dev/null); then
        
        STAGE_COUNT=$(echo "$PIPELINE_DETAILS" | wc -w)
        echo "   Stages: $STAGE_COUNT"
    fi
    echo ""
done

echo "📈 Summary:"
echo "   Total CodePipeline pipelines: $TOTAL_PIPELINES"
echo "   Inactive pipelines: $INACTIVE_PIPELINES"

if [ "$INACTIVE_PIPELINES" -gt 0 ]; then
    echo "⚠️  Recommendation: Consider archiving or removing inactive CodePipeline pipelines"
fi