#!/bin/bash
# check_trusted_advisor.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "🔍 Checking AWS Trusted Advisor findings"

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Note: Trusted Advisor is a global service, but we'll check what we can
echo "📊 Checking available Trusted Advisor checks..."

# Check if we have Business Support or higher for detailed TA checks
if SUPPORT_PLAN=$(aws support describe-trusted-advisor-checks --language en --query 'checks[0]' --output text 2>/dev/null); then
    echo "✅ AWS Support plan allows Trusted Advisor access"
    
    # Get checks summary
    CHECKS=$(aws support describe-trusted-advisor-checks --language en --query 'checks[].[id,name,category]' --output json 2>/dev/null)
    
    if [ -n "$CHECKS" ]; then
        echo ""
        echo "🏷️ Available Check Categories:"
        echo "$CHECKS" | jq -r '.[] | "  - \(.[2]): \(.[1])"' | sort | uniq
        
        # Get check results (focus on cost optimization)
        echo ""
        echo "💰 Cost Optimization Findings:"
        if COST_CHECKS=$(aws support describe-trusted-advisor-check-result \
            --check-id "zXCkfM1nI3" \  # Idle Load Balancers (example)
            --query 'result' \
            --output json 2>/dev/null); then
            echo "   - Cost optimization data available"
        else
            echo "   ℹ️ Detailed check results require appropriate permissions"
        fi
    fi
else
    echo "ℹ️ Trusted Advisor detailed checks require Business/Enterprise Support plan"
    echo "📋 Basic checks available with all support plans:"
    echo "   - Service limits"
    echo "   - Security groups"
    echo "   - IAM use"
    echo "   - MFA on root account"
    echo "   - EBS public snapshots"
    echo "   - RDS public snapshots"
    echo "   - S3 bucket permissions"
fi

# Alternative: Check service limits (always available)
echo ""
echo "📏 Service Limits Check:"
if LIMITS=$(aws service-quotas list-service-quotas --service-code ec2 --query 'Quotas[?Status==`AVAILABLE`] | length(@)' 2>/dev/null); then
    echo "   ✅ Service limits API accessible"
else
    echo "   ℹ️ Service limits check requires additional permissions"
fi