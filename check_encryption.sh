#!/bin/bash
source ./utils.sh

log_info "🔐 Checking Encryption Status Across Services"
echo "------------------------------------------------"

# S3 Bucket Encryption
log_info "📦 S3 Bucket Encryption:"
buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
for bucket in $buckets; do
    encryption=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>/dev/null || echo "Not Encrypted")
    if [[ "$encryption" == "Not Encrypted" ]]; then
        log_warn "⚠️  S3 Bucket without encryption: $bucket"
    else
        log_success "✅ Encrypted S3 Bucket: $bucket"
    fi
done

# EBS Volume Encryption
log_info "💾 EBS Volume Encryption:"
volumes=$(aws ec2 describe-volumes --query 'Volumes[?Encrypted==`false`].VolumeId' --output text)
if [ -n "$volumes" ]; then
    for volume in $volumes; do
        log_warn "⚠️  Unencrypted EBS Volume: $volume"
    done
else
    log_success "✅ All EBS volumes are encrypted"
fi

# RDS Encryption
log_info "🗄️  RDS Encryption:"
instances=$(aws rds describe-db-instances --query 'DBInstances[?StorageEncrypted==`false`].DBInstanceIdentifier' --output text)
if [ -n "$instances" ]; then
    for instance in $instances; do
        log_warn "⚠️  Unencrypted RDS Instance: $instance"
    done
else
    log_success "✅ All RDS instances are encrypted"
fi