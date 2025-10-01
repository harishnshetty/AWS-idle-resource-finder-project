#####################################################################
#   ___ _                 _      ___         _       ___   _  _     
#  / __| |___ __ _ _ _ __| |_   / __|_  _ __| |_ ___| | | | || |    
# | (__| / -_) _` | '_/ _| ' \  \__ \ || (_-<  _/ -_) | | | __ |    
#  \___|_\___\__,_|_| \__|_||_| |___/\_, /__/\__\___|_| | |_||_|    
#                                   |__/                             
#
# To learn more, see https://maxat-akbanov.com/
#####################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

log_info "Checking CloudWatch Alarms in $REGION"
echo "--------------------------------------------"

# Get all CloudWatch alarms
alarms=$(aws cloudwatch describe-alarms \
  --query 'MetricAlarms[*].[AlarmName,StateValue,AlarmDescription,MetricName,ComparisonOperator,Threshold]' \
  --output json)

# Check if no alarms were found
if [ -z "$alarms" ] || [ "$alarms" == "[]" ]; then
  log_warn "⚠️ No CloudWatch alarms found in region $REGION"
  exit 0
fi

# Count alarms by state
total_alarms=$(echo "$alarms" | jq length)
ok_count=$(echo "$alarms" | jq -r '[.[] | select(.[1]=="OK")] | length')
alarm_count=$(echo "$alarms" | jq -r '[.[] | select(.[1]=="ALARM")] | length')
insufficient_data_count=$(echo "$alarms" | jq -r '[.[] | select(.[1]=="INSUFFICIENT_DATA")] | length')

# Display summary
log_info "📊 CloudWatch Alarms Summary:"
echo "    Total Alarms: $total_alarms"
echo "    ✅ OK: $ok_count"
echo "    🔴 ALARM: $alarm_count"
echo "    ⚠️ INSUFFICIENT_DATA: $insufficient_data_count"
echo ""

# Display alarms in ALARM state
if [ "$alarm_count" -gt 0 ]; then
  log_warn "🔴 Alarms in ALARM state:"
  echo "$alarms" | jq -r '.[] | select(.[1]=="ALARM") | 
    "    Alarm: \(.[0])\n    Metric: \(.[3])\n    Condition: \(.[4]) \(.[5])\n    Description: \(.[2] // "N/A")\n"' | sed 's/^/    /'
  echo ""
fi

# Display alarms with INSUFFICIENT_DATA
if [ "$insufficient_data_count" -gt 0 ]; then
  log_warn "⚠️ Alarms with INSUFFICIENT_DATA (may need configuration):"
  echo "$alarms" | jq -r '.[] | select(.[1]=="INSUFFICIENT_DATA") | 
    "    Alarm: \(.[0])\n    Metric: \(.[3])\n    Description: \(.[2] // "N/A")\n"' | sed 's/^/    /'
  echo ""
fi

# Check for critical missing alarms
log_info "🔍 Checking for common missing critical alarms:"

# Check for high CPU usage alarm
cpu_alarm_exists=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "HighCPUUtilization" \
  --query 'length(MetricAlarms)' \
  --output text)

if [ "$cpu_alarm_exists" -eq 0 ]; then
  log_warn "⚠️ No High CPU Utilization alarm found"
else
  log_success "✅ High CPU Utilization alarm exists"
fi

# Check for low disk space alarm
disk_alarm_exists=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "LowDiskSpace" \
  --query 'length(MetricAlarms)' \
  --output text)

if [ "$disk_alarm_exists" -eq 0 ]; then
  log_warn "⚠️ No Low Disk Space alarm found"
else
  log_success "✅ Low Disk Space alarm exists"
fi

# Check for high memory usage alarm
memory_alarm_exists=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "HighMemoryUtilization" \
  --query 'length(MetricAlarms)' \
  --output text)

if [ "$memory_alarm_exists" -eq 0 ]; then
  log_warn "⚠️ No High Memory Utilization alarm found"
else
  log_success "✅ High Memory Utilization alarm exists"
fi

# Check for billing alarm
billing_alarm_exists=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "Billing" \
  --query 'length(MetricAlarms)' \
  --output text)

if [ "$billing_alarm_exists" -eq 0 ]; then
  log_warn "💰 No Billing alarm found - consider setting up cost monitoring"
else
  log_success "💰 Billing alarm exists"
fi

echo ""
log_info "💡 Recommendations:"
log_info "   • Set up alarms for critical metrics (CPU, Memory, Disk, Billing)"
log_info "   • Review alarms in INSUFFICIENT_DATA state"
log_info "   • Investigate alarms in ALARM state promptly"
log_info "   • Use composite alarms for complex monitoring scenarios"

log_success "CloudWatch alarms check completed"