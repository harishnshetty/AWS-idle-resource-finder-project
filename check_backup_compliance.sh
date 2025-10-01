#!/bin/bash
source ./utils.sh

log_info "💾 Backup & Disaster Recovery Check"
echo "--------------------------------------"

# Check AWS Backup vaults and plans
backup_vaults=$(aws backup list-backup-vaults --query 'BackupVaultList[].BackupVaultName' --output text 2>/dev/null || echo "")

if [ -z "$backup_vaults" ]; then
    log_warn "⚠️  No AWS Backup vaults configured"
else
    log_success "✅ AWS Backup vaults: $backup_vaults"
    
    # Check backup plans
    plans=$(aws backup list-backup-plans --query 'BackupPlansList[].BackupPlanId' --output text)
    if [ -z "$plans" ]; then
        log_warn "⚠️  No backup plans configured"
    else
        log_success "✅ Backup plans: $(echo $plans | wc -w)"
    fi
fi

# Check RDS automated backups
rds_instances=$(aws rds describe-db-instances --query 'DBInstances[?BackupRetentionPeriod==`0`].DBInstanceIdentifier' --output text)
if [ -n "$rds_instances" ]; then
    for instance in $rds_instances; do
        log_warn "⚠️  RDS instance without backups: $instance"
    done
fi