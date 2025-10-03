#!/bin/bash
# check_lambda_old_runtimes.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "🔍 Checking for Lambda functions with outdated runtimes in $REGION"

# Define outdated runtimes (adjust as needed)
OUTDATED_RUNTIMES=("nodejs10.x" "nodejs8.10" "nodejs6.10" "nodejs4.3" "nodejs4.3-edge" 
                   "python2.7" "python3.6" "ruby2.5" "dotnetcore2.1" "dotnetcore1.0"
                   "java8")

TOTAL_FUNCTIONS=0
OUTDATED_FUNCTIONS=0

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
    RUNTIME=$(echo "$FUNCTION" | jq -r '.Runtime')
    LAST_MODIFIED=$(echo "$FUNCTION" | jq -r '.LastModified')
    
    IS_OUTDATED=false
    for OLD_RUNTIME in "${OUTDATED_RUNTIMES[@]}"; do
        if [ "$RUNTIME" == "$OLD_RUNTIME" ]; then
            IS_OUTDATED=true
            break
        fi
    done
    
    echo "  - $FUNCTION_NAME"
    echo "    Runtime: $RUNTIME, Last Modified: $LAST_MODIFIED"
    
    if [ "$IS_OUTDATED" = true ]; then
        echo "    ⚠️  OUTDATED: Consider upgrading to a newer runtime version"
        OUTDATED_FUNCTIONS=$((OUTDATED_FUNCTIONS + 1))
    else
        echo "    ✅ Runtime OK"
    fi
    echo ""
done

echo "📈 Summary:"
echo "   Total functions: $TOTAL_FUNCTIONS"
echo "   Outdated runtimes: $OUTDATED_FUNCTIONS"

if [ "$OUTDATED_FUNCTIONS" -gt 0 ]; then
    echo "⚠️  Recommendation: Update outdated runtimes for security patches and better performance"
fi