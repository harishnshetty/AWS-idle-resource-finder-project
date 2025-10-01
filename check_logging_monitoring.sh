#!/bin/bash
source ./utils.sh

log_info "📝 Logging & Monitoring Audit"
echo "--------------------------------"

# CloudTrail check
cloudtrail=$(aws cloudtrail describe-trails --query 'trailList[?IsMultiRegionTrail==`true`]' --output json 2>/dev/null || echo "[]")
if [ "$cloudtrail" == "[]" ]; then
    log_warn "⚠️  No multi-region CloudTrail trail found"
else
    log_success "✅ Multi-region CloudTrail enabled"
fi

# VPC Flow Logs
vpcs=$(aws ec2 describe-vpcs --query 'Vpcs[].VpcId' --output text)
for vpc in $vpcs; do
    flow_logs=$(aws ec2 describe-flow-logs --filter Name=resource-id,Values=$vpc --query 'FlowLogs[0].FlowLogId' --output text)
    if [ -z "$flow_logs" ]; then
        log_warn "⚠️  VPC without flow logs: $vpc"
    fi
done