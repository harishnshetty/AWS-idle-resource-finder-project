#!/bin/bash
# check_large_lambda_packages.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
SIZE_THRESHOLD=50 # MB

echo "🔍 Checking for large Lambda deployment packages (>${SIZE_THRESHOLD}MB) in $REGION"

TOTAL_FUNCTIONS=0
LARGE_FUNCTIONS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Get list of Lambda functions
if ! FUNCTIONS=$(aws lambda list-functions --region "$REGION" --query 'Functions[]' --output json 2>/dev/null); then
    echo "❌ No permission to list Lambda functions"
    exit 0
fi

if [ -z "$FUNCTIONS" ] || [ "$FUNCTIONS" == "null" ]; then
    echo "✅ No Lambda functions found in region $REGION"
    exit 0
fi

echo "$FUNCTIONS" | jq -c '.[]' | while read -r FUNCTION; do
    TOTAL_FUNCTIONS=$((TOTAL_FUNCTIONS + 1))
    FUNCTION_NAME=$(echo "$FUNCTION" | jq -r '.FunctionName')
    CODE_SIZE=$(echo "$FUNCTION" | jq -r '.CodeSize')
    SIZE_MB=$((CODE_SIZE / 1024 / 1024))
    RUNTIME=$(echo "$FUNCTION" | jq -r '.Runtime')
    
    echo "  - $FUNCTION_NAME"
    echo "    Runtime: $RUNTIME, Size: ${SIZE_MB}MB"
    
    if [ "$SIZE_MB" -gt "$SIZE_THRESHOLD" ]; then
        echo "    ⚠️  LARGE: ${SIZE_MB}MB exceeds ${SIZE_THRESHOLD}MB threshold"
        LARGE_FUNCTIONS=$((LARGE_FUNCTIONS + 1))
        
        # Check for layers
        LAYERS=$(echo "$FUNCTION" | jq -r '.Layers | length')
        if [ "$LAYERS" -gt 0 ]; then
            echo "    📦 Uses $LAYERS layers (consider reviewing layer dependencies)"
        fi
    else
        echo "    ✅ Size OK"
    fi
    echo ""
done

echo "📈 Summary:"
echo "   Total functions: $TOTAL_FUNCTIONS"
echo "   Large packages: $LARGE_FUNCTIONS"

if [ "$LARGE_FUNCTIONS" -gt 0 ]; then
    echo "⚠️  Recommendation: Large packages increase cold start times. Consider using layers or optimizing dependencies"
fi