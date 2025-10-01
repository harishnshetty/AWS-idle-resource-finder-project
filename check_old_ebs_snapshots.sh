#####################################################################
#  ___  ___  ___    ___  _              _   
# | __|| _ )/ __|  / __|| |_   ___  __ | |__
# | _| | _ \\__ \ | (__ | ' \ / -_)/ _|| / /
# |___||___/|___/  \___||_||_|\___|\__||_\_\
#  ___                  _                    _          
# / __| _ __  __ _  ___| |_  ___  _ _  __ _ | |_  ___   
# \__ \| '_ \/ _` |(_-<|  _|/ -_)| '_|/ _` ||  _|/ -_)  
# |___/| .__/\__,_|/__/ \__|\___||_|  \__,_| \__|\___|  
#      |_|                                              
#
# To learn more, see https://maxat-akbanov.com/
#####################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

# Define threshold (in days) for identifying old EBS snapshots
THRESHOLD_DAYS=90
log_info "Checking for EBS snapshots older than $THRESHOLD_DAYS days in $REGION"
echo "--------------------------------------------------------------------------"

# Calculate cutoff date
cutoff_date=$(date -u -d "$THRESHOLD_DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")

# Get all EBS snapshots owned by this account
snapshots=$(aws ec2 describe-snapshots \
  --owner-ids "$ACCOUNT_ID" \
  --query "Snapshots[?StartTime<'$cutoff_date'].[SnapshotId,VolumeId,StartTime,VolumeSize,Description,State]" \
  --output json)

# Check if no old snapshots were found
if [ -z "$snapshots" ] || [ "$snapshots" == "[]" ]; then
  log_success "✅ No EBS snapshots older than $THRESHOLD_DAYS days found."
  exit 0
fi

# Parse and display old snapshots
echo "$snapshots" | jq -r '.[] | 
  "💾 Old Snapshot: \(.[0])\n    Volume: \(.[1])\n    Created: \(.[2])\n    Size: \(.[3]) GiB\n    State: \(.[5])\n    Description: \(.[4] // "N/A")\n"'

# Calculate total storage cost
total_size=$(echo "$snapshots" | jq '[.[] | .[3]] | add')
estimated_cost=$(echo "scale=2; $total_size * 0.05 * 30" | bc)  # ~$0.05 per GB-month

# Count and show summary
count=$(echo "$snapshots" | jq length)
log_warn "📊 Found $count EBS snapshots older than $THRESHOLD_DAYS days"
log_warn "💰 Estimated monthly storage cost: \$$estimated_cost"
log_info "💡 Consider deleting unused snapshots to reduce storage costs"