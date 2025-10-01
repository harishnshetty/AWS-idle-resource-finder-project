#####################################################################
#   ___          ___                  _                    _          
#  / _ \ _ _    / __| _ __  __ _  ___| |_  ___  _ _  __ _ | |_  ___   
# | (_) | ' \  | (__ | '_ \/ _` |(_-<|  _|/ -_)| '_|/ _` ||  _|/ -_)  
#  \___/|_||_|  \___|| .__/\__,_|/__/ \__|\___||_|  \__,_| \__|\___|  
#                    |_|                                              
#
# To learn more, see https://maxat-akbanov.com/
#####################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

log_info "Checking for orphaned EBS snapshots (without existing volumes) in $REGION"
echo "---------------------------------------------------------------------------"

# Get all EBS snapshots owned by this account
snapshots=$(aws ec2 describe-snapshots \
  --owner-ids "$ACCOUNT_ID" \
  --query "Snapshots[*].[SnapshotId,VolumeId,StartTime,VolumeSize,Description]" \
  --output json)

# Get all existing EBS volumes
existing_volumes=$(aws ec2 describe-volumes \
  --query "Volumes[*].VolumeId" \
  --output text)

orphaned_count=0

echo "$snapshots" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r snapshot_id volume_id start_time volume_size description; do
  if ! echo "$existing_volumes" | grep -q "$volume_id"; then
    log_warn "💾 Orphaned Snapshot: $snapshot_id"
    echo "    Original Volume: $volume_id (deleted)"
    echo "    Created: $start_time"
    echo "    Size: $volume_size GiB"
    echo "    Description: ${description:-N/A}"
    echo ""
    ((orphaned_count++))
  else
    log_success "✅ Snapshot with existing volume: $snapshot_id"
  fi
done

log_info "📊 Total orphaned snapshots found: $orphaned_count"
log_info "💡 Orphaned snapshots are from deleted volumes - consider if they're still needed"