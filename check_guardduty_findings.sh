#!/bin/bash
source ./utils.sh

log_info "🛡️  GuardDuty Findings Check"
echo "-------------------------------"

# Check if GuardDuty is enabled
guardduty_enabled=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text 2>/dev/null || echo "Disabled")

if [ "$guardduty_enabled" == "Disabled" ]; then
    log_warn "⚠️  GuardDuty is not enabled in this region"
else
    # Get recent findings
    findings=$(aws guardduty list-findings --detector-id "$guardduty_enabled" --query 'FindingIds' --output text 2>/dev/null)
    if [ -n "$findings" ]; then
        log_warn "🚨 GuardDuty has active findings: $(echo $findings | wc -w)"
        # Get high severity findings
        high_findings=$(aws guardduty list-findings --detector-id "$guardduty_enabled" --finding-criteria '{"Criterion":{"severity":{"Gte":7}}}' --query 'FindingIds' --output text 2>/dev/null)
        if [ -n "$high_findings" ]; then
            log_warn "🔴 HIGH Severity Findings: $(echo $high_findings | wc -w)"
        fi
    else
        log_success "✅ No active GuardDuty findings"
    fi
fi