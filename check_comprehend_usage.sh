#!/bin/bash
# check_comprehend_usage.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "🔍 Checking Amazon Comprehend usage in $REGION"

TOTAL_JOBS=0
ACTIVE_JOBS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

echo "📊 Comprehend Usage Analysis:"

# Check for dominant language detection jobs
echo "🈯 Dominant Language Detection Jobs:"
if LANG_JOBS=$(aws comprehend list-dominant-language-detection-jobs --region "$REGION" --query 'DominantLanguageDetectionJobPropertiesList' --output json 2>/dev/null); then
    echo "$LANG_JOBS" | jq -c '.[]' | while read -r JOB; do
        TOTAL_JOBS=$((TOTAL_JOBS + 1))
        JOB_NAME=$(echo "$JOB" | jq -r '.JobName')
        STATUS=$(echo "$JOB" | jq -r '.JobStatus')
        SUBMITTED=$(echo "$JOB" | jq -r '.SubmitTime')
        
        echo "  - $JOB_NAME"
        echo "    Status: $STATUS, Submitted: $SUBMITTED"
        
        if [ "$STATUS" == "IN_PROGRESS" ] || [ "$STATUS" == "SUBMITTED" ]; then
            ACTIVE_JOBS=$((ACTIVE_JOBS + 1))
        fi
    done
fi

# Check for entity recognition jobs
echo ""
echo "🏷️ Entity Recognition Jobs:"
if ENTITY_JOBS=$(aws comprehend list-entities-detection-jobs --region "$REGION" --query 'EntitiesDetectionJobPropertiesList' --output json 2>/dev/null); then
    echo "$ENTITY_JOBS" | jq -c '.[]' | while read -r JOB; do
        TOTAL_JOBS=$((TOTAL_JOBS + 1))
        JOB_NAME=$(echo "$JOB" | jq -r '.JobName')
        STATUS=$(echo "$JOB" | jq -r '.JobStatus')
        
        echo "  - $JOB_NAME"
        echo "    Status: $STATUS"
        
        if [ "$STATUS" == "IN_PROGRESS" ] || [ "$STATUS" == "SUBMITTED" ]; then
            ACTIVE_JOBS=$((ACTIVE_JOBS + 1))
        fi
    done
fi

# Check for custom classifiers
echo ""
echo "🔧 Custom Classifiers:"
if CLASSIFIERS=$(aws comprehend list-document-classifiers --region "$REGION" --query 'DocumentClassifierPropertiesList' --output json 2>/dev/null); then
    CLASSIFIER_COUNT=$(echo "$CLASSIFIERS" | jq -r 'length')
    echo "  Total custom classifiers: $CLASSIFIER_COUNT"
    
    echo "$CLASSIFIERS" | jq -c '.[]' | while read -r CLASSIFIER; do
        CLASSIFIER_NAME=$(echo "$CLASSIFIER" | jq -r '.DocumentClassifierName')
        STATUS=$(echo "$CLASSIFIER" | jq -r '.Status')
        echo "  - $CLASSIFIER_NAME: $STATUS"
    done
fi

echo ""
echo "📈 Summary:"
echo "   Total Comprehend jobs: $TOTAL_JOBS"
echo "   Active jobs: $ACTIVE_JOBS"
echo "   Custom classifiers: ${CLASSIFIER_COUNT:-0}"

if [ "$ACTIVE_JOBS" -gt 0 ]; then
    echo "✅ Comprehend is actively being used"
else
    echo "ℹ️  No active Comprehend jobs detected"
fi