#####################################################################
#   ___  _  _     ___                      _ 
#  / _ \| |(_)   / __| ___  _ _  _ _  ___ (_)
# | (_) | || |  | (__ / _ \| '_|| '_|/ -_) _ 
#  \___/|_||_|   \___|\___/|_|  |_|  \___|(_)
#
# To learn more, see https://maxat-akbanov.com/
#####################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

# Define threshold (in days) for identifying old AMIs
THRESHOLD_DAYS=90
log_info "Checking for AMIs older than $THRESHOLD_DAYS days in $REGION"
echo "----------------------------------------------------------------"

# Calculate cutoff date
cutoff_date=$(date -u -d "$THRESHOLD_DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")

# Get all AMIs owned by this account
amis=$(aws ec2 describe-images \
  --owners "$ACCOUNT_ID" \
  --query "Images[?CreationDate<'$cutoff_date'].[ImageId,Name,CreationDate,Description,State]" \
  --output json)

# Check if no old AMIs were found
if [ -z "$amis" ] || [ "$amis" == "[]" ]; then
  log_success "✅ No AMIs older than $THRESHOLD_DAYS days found."
  exit 0
fi

# Parse and display old AMIs
echo "$amis" | jq -r '.[] | 
  "🖼️  Old AMI: \(.[0])\n    Name: \(.[1])\n    Created: \(.[2])\n    State: \(.[4])\n    Description: \(.[3] // "N/A")\n"'

# Count and show summary
count=$(echo "$amis" | jq length)
log_warn "📊 Found $count AMIs older than $THRESHOLD_DAYS days"
log_info "💡 Consider deregistering unused AMIs to save storage costs"