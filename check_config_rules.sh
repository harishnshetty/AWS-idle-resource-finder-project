#!/bin/bash
source ./utils.sh

log_info "⚙️  AWS Config Rules Compliance"
echo "---------------------------------"

# Check if AWS Config is enabled
config_enabled=$(aws configservice describe-configuration-recorders --query 'ConfigurationRecorders[0].name' --output text 2>/dev/null || echo "Disabled")

if [ "$config_enabled" == "Disabled" ]; then
    log_warn "⚠️  AWS Config is not enabled"
else
    # Get non-compliant rules
    non_compliant=$(aws configservice describe-compliance-by-config-rule --query 'ComplianceByConfigRules[?Compliance.ComplianceType==`NON_COMPLIANT`]' --output json 2>/dev/null || echo "[]")
    
    count=$(echo "$non_compliant" | jq length)
    if [ "$count" -gt 0 ]; then
        log_warn "⚠️  $count non-compliant Config rules found"
        echo "$non_compliant" | jq -r '.[] | "    Rule: \(.ConfigRuleName)"'
    else
        log_success "✅ All Config rules are compliant"
    fi
fi