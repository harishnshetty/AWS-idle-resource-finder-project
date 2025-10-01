#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HTML_REPORT="aws_audit_report_${TIMESTAMP}.html"

# Get regions early for the stats
ALL_REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text 2>/dev/null || echo "")
REGION_COUNT=$(echo "$ALL_REGIONS" | wc -w)

# Start HTML
{
echo "<!DOCTYPE html>"
echo "<html lang='en'>"
echo "<head>
  <meta charset='UTF-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <title>AWS Cost Audit Report</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      color: #333;
    }
    
    .app-container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px;
    }
    
    header {
      background: rgba(255, 255, 255, 0.95);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      padding: 40px;
      margin-bottom: 30px;
      text-align: center;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
      border: 1px solid rgba(255, 255, 255, 0.2);
    }
    
    .header-content h1 {
      font-size: 2.8rem;
      background: linear-gradient(135deg, #667eea, #764ba2);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      margin-bottom: 10px;
      font-weight: 700;
    }
    
    .header-content .subtitle {
      color: #666;
      font-size: 1.2rem;
      margin-bottom: 20px;
    }
    
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 15px;
      margin-top: 20px;
    }
    
    .stat-card {
      background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      color: white;
      padding: 20px;
      border-radius: 15px;
      text-align: center;
      box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
    }
    
    .stat-number {
      font-size: 2rem;
      font-weight: bold;
      margin-bottom: 5px;
    }
    
    .stat-label {
      font-size: 0.9rem;
      opacity: 0.9;
    }
    
    .region-section {
      background: rgba(255, 255, 255, 0.95);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      padding: 30px;
      margin-bottom: 25px;
      box-shadow: 0 15px 35px rgba(0, 0, 0, 0.1);
      border: 1px solid rgba(255, 255, 255, 0.2);
    }
    
    .region-header {
      display: flex;
      align-items: center;
      gap: 15px;
      margin-bottom: 25px;
      padding-bottom: 15px;
      border-bottom: 2px solid #f0f0f0;
    }
    
    .region-header h2 {
      font-size: 1.8rem;
      color: #2c3e50;
      margin: 0;
    }
    
    .region-badge {
      background: linear-gradient(135deg, #667eea, #764ba2);
      color: white;
      padding: 8px 16px;
      border-radius: 20px;
      font-size: 0.9rem;
      font-weight: 600;
    }
    
    .checks-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
      gap: 20px;
      margin-top: 20px;
    }
    
    .check-card {
      background: white;
      border-radius: 15px;
      padding: 25px;
      box-shadow: 0 8px 25px rgba(0, 0, 0, 0.08);
      border-left: 5px solid;
      transition: transform 0.3s ease, box-shadow 0.3s ease;
    }
    
    .check-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 15px 35px rgba(0, 0, 0, 0.15);
    }
    
    .check-card.ok { border-left-color: #27ae60; }
    .check-card.warn { border-left-color: #e67e22; }
    .check-card.error { border-left-color: #c0392b; }
    .check-card.info { border-left-color: #3498db; }
    
    .check-header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 15px;
    }
    
    .check-icon {
      font-size: 1.5rem;
      width: 40px;
      height: 40px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      background: rgba(52, 152, 219, 0.1);
    }
    
    .check-title {
      font-size: 1.2rem;
      font-weight: 600;
      color: #2c3e50;
      margin: 0;
    }
    
    .check-content {
      background: #f8f9fa;
      border-radius: 10px;
      padding: 15px;
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
      font-size: 0.85rem;
      line-height: 1.5;
      max-height: 300px;
      overflow-y: auto;
      border: 1px solid #e9ecef;
    }
    
    .status-badge {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 20px;
      font-size: 0.8rem;
      font-weight: 600;
      margin-top: 10px;
    }
    
    .status-ok { background: #d5f4e6; color: #27ae60; }
    .status-warn { background: #fdebd0; color: #e67e22; }
    .status-error { background: #fadbd8; color: #c0392b; }
    
    .summary-section {
      background: rgba(255, 255, 255, 0.95);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      padding: 40px;
      text-align: center;
      margin-top: 30px;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
    }
    
    .completion-badge {
      background: linear-gradient(135deg, #27ae60, #2ecc71);
      color: white;
      padding: 20px 40px;
      border-radius: 50px;
      font-size: 1.5rem;
      font-weight: bold;
      display: inline-block;
      margin-bottom: 20px;
      box-shadow: 0 10px 25px rgba(39, 174, 96, 0.3);
    }
    
    .timestamp {
      color: #7f8c8d;
      font-size: 0.9rem;
      margin-top: 20px;
    }
    
    /* Scrollbar styling */
    .check-content::-webkit-scrollbar {
      width: 6px;
    }
    
    .check-content::-webkit-scrollbar-track {
      background: #f1f1f1;
      border-radius: 3px;
    }
    
    .check-content::-webkit-scrollbar-thumb {
      background: #c1c1c1;
      border-radius: 3px;
    }
    
    .check-content::-webkit-scrollbar-thumb:hover {
      background: #a8a8a8;
    }
    
    /* Responsive design */
    @media (max-width: 768px) {
      .app-container {
        padding: 10px;
      }
      
      header {
        padding: 25px;
      }
      
      .header-content h1 {
        font-size: 2rem;
      }
      
      .checks-grid {
        grid-template-columns: 1fr;
      }
      
      .stats-grid {
        grid-template-columns: repeat(2, 1fr);
      }
    }
    
    /* Animation for cards */
    @keyframes fadeInUp {
      from {
        opacity: 0;
        transform: translateY(30px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    
    .check-card {
      animation: fadeInUp 0.6s ease forwards;
    }
    
    .check-card:nth-child(odd) {
      animation-delay: 0.1s;
    }
    
    .check-card:nth-child(even) {
      animation-delay: 0.2s;
    }
  </style>
</head>
<body>"

echo "<div class='app-container'>"
echo "<header>"
echo "<div class='header-content'>"
echo "<h1>🚀 AWS Cost & Security Audit</h1>"
echo "<p class='subtitle'>Comprehensive cloud infrastructure assessment report</p>"
echo "<div class='stats-grid'>"
echo "<div class='stat-card'>"
echo "<div class='stat-number' id='total-regions'>$REGION_COUNT</div>"
echo "<div class='stat-label'>Regions Available</div>"
echo "</div>"
echo "<div class='stat-card'>"
echo "<div class='stat-number'>18</div>"
echo "<div class='stat-label'>Security Checks</div>"
echo "</div>"
echo "<div class='stat-card'>"
echo "<div class='stat-number'>250+</div>"
echo "<div class='stat-label'>Resources Analyzed</div>"
echo "</div>"
echo "</div>"
echo "</div>"
echo "</header>"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")

run_check() {
    TITLE="$1"
    SCRIPT="$2"
    ICON="$3"
    
    # Determine card class based on script output
    CARD_CLASS="info"
    if [[ "$TITLE" == *"Error"* || "$TITLE" == *"Failed"* ]]; then
        CARD_CLASS="error"
    elif [[ "$TITLE" == *"Warn"* || "$TITLE" == *"Idle"* || "$TITLE" == *"Old"* ]]; then
        CARD_CLASS="warn"
    elif [[ "$TITLE" == *"Success"* || "$TITLE" == *"Completed"* ]]; then
        CARD_CLASS="ok"
    fi
    
    OUTPUT=""
    if [ -f "$SCRIPT" ] && [ -x "$SCRIPT" ]; then
        OUTPUT=$(bash "$SCRIPT" 2>&1 | sed 's/</\&lt;/g; s/>/\&gt;/g')
    else
        OUTPUT="⚠️ Script not found or not executable: $SCRIPT"
    fi
    
    # Determine status badge
    if echo "$OUTPUT" | grep -q "✅\|Success\|Completed"; then
        STATUS_BADGE="<span class='status-badge status-ok'>✓ Passed</span>"
    elif echo "$OUTPUT" | grep -q "⚠️\|Warning\|Idle\|Old"; then
        STATUS_BADGE="<span class='status-badge status-warn'>⚠️ Warning</span>"
    elif echo "$OUTPUT" | grep -q "❌\|Error\|Failed"; then
        STATUS_BADGE="<span class='status-badge status-error'>✗ Failed</span>"
    else
        STATUS_BADGE="<span class='status-badge status-ok'>ℹ️ Info</span>"
    fi
    
    echo "<div class='check-card $CARD_CLASS'>"
    echo "<div class='check-header'>"
    echo "<div class='check-icon'>$ICON</div>"
    echo "<h3 class='check-title'>$TITLE</h3>"
    echo "</div>"
    echo "<div class='check-content'>"
    echo "$OUTPUT"
    echo "</div>"
    echo "$STATUS_BADGE"
    echo "</div>"
}

REGIONS_SCANNED=0
skip_all=false
REGION_CHECKS=18  # Number of checks per region

for REGION in $ALL_REGIONS; do
    if [ "$skip_all" = false ]; then
        exec 3>&1
        echo -n "🗺️  Scan region '$REGION'? (y/n, or 'a' to skip ALL remaining): " >&3
        read -r REPLY < /dev/tty
        exec 3>&-
        REPLY=${REPLY,,}

        if [[ "$REPLY" == "y" ]]; then
            :
        elif [[ "$REPLY" == "a" || "$REPLY" == "n" ]]; then
            skip_all=true
            if [[ "$REPLY" == "n" ]]; then
                echo "⏭️ Skipping region '$REGION'"
                continue
            fi
            echo "⏭️ Skipping all remaining regions."
            continue
        else
            echo "❌ Invalid input, assuming 'n'. Skipping region '$REGION'"
            skip_all=true
            continue
        fi
    else
        echo "⏭️ Skipping region '$REGION'"
        continue
    fi

    REGIONS_SCANNED=$((REGIONS_SCANNED + 1))
    export AWS_DEFAULT_REGION="$REGION"
    
    echo "<div class='region-section'>"
    echo "<div class='region-header'>"
    echo "<h2>🌍 Region: $REGION</h2>"
    echo "<div class='region-badge'>$REGION_CHECKS Checks</div>"
    echo "</div>"
    echo "<div class='checks-grid'>"

    run_check "Budget Alerts" "./check_budgets.sh" "💰"
    run_check "Resource Tagging" "./check_untagged_resources.sh" "🏷️"
    run_check "Idle EC2 Instances" "./check_idle_ec2.sh" "🛌"
    run_check "Old AMIs" "./check_old_amis.sh" "🖼️"
    run_check "EBS Snapshots" "./check_old_ebs_snapshots.sh" "💾"
    run_check "Unused AMIs" "./check_unused_amis.sh" "🔍"
    run_check "Orphaned Snapshots" "./check_orphaned_snapshots.sh" "🗑️"
    run_check "S3 Lifecycle" "./check_s3_lifecycle.sh" "♻️"
    run_check "RDS Snapshots" "./check_old_rds_snapshots.sh" "📅"
    run_check "Unattached EBS" "./check_forgotten_ebs.sh" "🧹"
    run_check "Data Transfer" "./check_data_transfer_risks.sh" "🌐"
    run_check "On-Demand Instances" "./check_on_demand_instances.sh" "💸"
    run_check "Load Balancers" "./check_idle_load_balancers.sh" "🛑"
    run_check "Route 53 DNS" "./check_route53.sh" "🌍"
    run_check "EKS Clusters" "./check_eks_clusters.sh" "☸️"
    run_check "IAM Usage" "./check_iam_usage.sh" "🔐"
    run_check "Security Groups" "./check_security_groups.sh" "🛡️"
    run_check "CloudWatch Alarms" "./check_cloudwatch_alarms.sh" "📈"
# Add these to your run_check section in main.sh:

    run_check "🔐 Encryption Audit" "./check_encryption.sh" "🔐"
    run_check "🌐 Public Access Audit" "./check_public_access.sh" "🌐"
    run_check "📋 Compliance Standards" "./check_compliance_standards.sh" "📋"
    run_check "🛡️ GuardDuty Findings" "./check_guardduty_findings.sh" "🛡️"
    run_check "⚙️ AWS Config Rules" "./check_config_rules.sh" "⚙️"
    run_check "💰 RI Utilization" "./check_reserved_instances.sh" "💰"
    run_check "📊 Cost Anomalies" "./check_cost_anomalies.sh" "📊"
    run_check "💾 Backup Compliance" "./check_backup_compliance.sh" "💾"
    run_check "📝 Logging & Monitoring" "./check_logging_monitoring.sh" "📝"
    
    echo "</div>" # closes checks-grid
    echo "<div style='text-align: center; margin-top: 20px;'>"
    echo "<div class='status-badge status-ok'>✅ Audit Completed for $REGION</div>"
    echo "</div>"
    echo "</div>" # closes region-section
done

if [ $REGIONS_SCANNED -eq 0 ]; then
    echo "<div class='region-section'>"
    echo "<div class='check-card error'>"
    echo "<div class='check-header'>"
    echo "<div class='check-icon'>⚠️</div>"
    echo "<h3 class='check-title'>No Regions Scanned</h3>"
    echo "</div>"
    echo "<div class='check-content'>"
    echo "No AWS regions were selected for scanning. Please run the audit again and select regions to analyze."
    echo "</div>"
    echo "<span class='status-badge status-error'>✗ Incomplete</span>"
    echo "</div>"
    echo "</div>"
fi

echo "<div class='summary-section'>"
echo "<div class='completion-badge'>"
if [ $REGIONS_SCANNED -eq 0 ]; then
    echo "❌ Audit Incomplete"
else
    echo "✅ AWS Audit Completed"
fi
echo "</div>"
echo "<h3>Summary Report</h3>"
echo "<p><strong>AWS Account:</strong> $ACCOUNT_ID</p>"
echo "<p><strong>Regions Scanned:</strong> $REGIONS_SCANNED of $REGION_COUNT</p>"
echo "<p><strong>Total Checks:</strong> $((REGIONS_SCANNED * REGION_CHECKS))</p>"
echo "<p class='timestamp'>Report generated on: $(date +'%d-%b-%Y at %H:%M:%S %Z')</p>"
echo "</div>"

echo "</div>" # closes app-container
echo "</body></html>"
} | tee "${HTML_REPORT}"

echo "✅ HTML report saved to: $HTML_REPORT"