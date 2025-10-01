#!/bin/bash
source ./utils.sh

log_info "💰 Reserved Instance Utilization"
echo "-----------------------------------"

# Get RI coverage
ri_coverage=$(aws ec2 describe-reserved-instances --query 'ReservedInstances[?State==`active`]' --output json 2>/dev/null || echo "[]")

if [ "$ri_coverage" == "[]" ]; then
    log_warn "⚠️  No active Reserved Instances found"
else
    total_ri=$(echo "$ri_coverage" | jq 'length')
    log_success "✅ $total_ri active Reserved Instances"
    
    # Check for expiring RIs
    expiring_soon=$(aws ec2 describe-reserved-instances --query 'ReservedInstances[?State==`active` && End < `'"$(date -d "+30 days" +%Y-%m-%d)"'`].ReservedInstancesId' --output text)
    if [ -n "$expiring_soon" ]; then
        log_warn "⚠️  Reserved Instances expiring soon: $expiring_soon"
    fi
fi