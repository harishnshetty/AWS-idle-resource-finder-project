#!/bin/bash
source ./utils.sh

log_info "🌐 Checking Public Access to Resources"
echo "----------------------------------------"

# Public S3 Buckets
log_info "📦 Public S3 Buckets:"
buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
for bucket in $buckets; do
    acl=$(aws s3api get-bucket-acl --bucket "$bucket" --query 'Grants[?Grantee.URI==`http://acs.amazonaws.com/groups/global/AllUsers`]' --output text 2>/dev/null)
    if [ -n "$acl" ]; then
        log_warn "🚨 PUBLIC S3 Bucket: $bucket"
    fi
done

# Public ECR Repositories
log_info "📷 ECR Repository Public Access:"
repos=$(aws ecr describe-repositories --query 'repositories[?repositoryUri]' --output json 2>/dev/null || echo "[]")
echo "$repos" | jq -r '.[] | "    Repository: \(.repositoryName)"'

# Public AMIs
log_info "🖼️  Public AMIs:"
public_amis=$(aws ec2 describe-images --owners self --query 'Images[?Public==`true`].ImageId' --output text)
if [ -n "$public_amis" ]; then
    for ami in $public_amis; do
        log_warn "⚠️  Public AMI: $ami"
    done
else
    log_success "✅ No public AMIs found"
fi