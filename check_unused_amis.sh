#####################################################################
#  _   _                    ___  _  _   ___  ___ 
# | | | | ___  _ _  _  _   / __|| \| | / __|/ __|
# | |_| |/ _ \| ' \| || | | (__ | .` | \__ \\__ \
#  \___/ \___/|_||_|\_, |  \___||_|\_| |___/|___/
#                   |__/                         
#
# To learn more, see https://maxat-akbanov.com/
#####################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

log_info "Checking for unused AMIs (not associated with any EC2 instance) in $REGION"
echo "------------------------------------------------------------------------------"

# Get all AMIs owned by this account
amis=$(aws ec2 describe-images \
  --owners "$ACCOUNT_ID" \
  --query "Images[*].[ImageId,Name,CreationDate]" \
  --output json)

# Get all running/stopped EC2 instances and their AMIs
used_amis=$(aws ec2 describe-instances \
  --query "Reservations[*].Instances[*].ImageId" \
  --output text)

# Get all launch configurations and templates (for ASG)
asg_amis=$(aws autoscaling describe-launch-configurations \
  --query "LaunchConfigurations[*].ImageId" \
  --output text 2>/dev/null || echo "")

# Combine all used AMIs
all_used_amis=$(echo "$used_amis $asg_amis" | tr ' ' '\n' | sort | uniq)

unused_count=0

echo "$amis" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r ami_id name creation_date; do
  if ! echo "$all_used_amis" | grep -q "$ami_id"; then
    log_warn "🖼️  Unused AMI: $ami_id"
    echo "    Name: $name"
    echo "    Created: $creation_date"
    echo ""
    ((unused_count++))
  else
    log_success "✅ AMI in use: $ami_id ($name)"
  fi
done

log_info "📊 Total unused AMIs found: $unused_count"
log_info "💡 Unused AMIs can be deregistered to save costs"