#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HTML_REPORT="aws_audit_report_${TIMESTAMP}.html"

# Hardcoded AWS Regions list (as of Oct 2025)
VALID_REGIONS=(
    us-east-1 us-east-2 us-west-1 us-west-2
    ca-central-1 ca-west-1
    af-south-1
    eu-north-1 eu-central-1 eu-central-2
    eu-west-1 eu-west-2 eu-west-3
    eu-south-1 eu-south-2
    il-central-1
    sa-east-1
    me-south-1 me-central-1
    mx-central-1
    ap-south-1 ap-northeast-1 ap-northeast-2 ap-northeast-3 ap-northeast-4
    ap-southeast-1 ap-southeast-2 ap-southeast-3 ap-southeast-4 ap-southeast-5
    ap-east-1
)

echo "=============================================="
echo "Available AWS Regions:"
for i in "${!VALID_REGIONS[@]}"; do
    echo "$((i+1)). ${VALID_REGIONS[$i]}"
done
echo "=============================================="

# Ask user for regions
read -p "Enter region(s) separated by commas (e.g. us-east-1,ap-south-1,eu-central-1): " USER_REGIONS

# Convert comma separated input into array and validate
IFS=',' read -r -a SELECTED_REGIONS <<< "$USER_REGIONS"

# Validate regions
VALIDATED_REGIONS=()
for region in "${SELECTED_REGIONS[@]}"; do
    region=$(echo "$region" | xargs)  # Trim whitespace
    if [[ " ${VALID_REGIONS[@]} " =~ " ${region} " ]]; then
        VALIDATED_REGIONS+=("$region")
        echo "✅ Valid region: $region"
    else
        echo "⚠️  Warning: '$region' is not a valid AWS region. Skipping."
    fi
done

SELECTED_REGIONS=("${VALIDATED_REGIONS[@]}")
REGION_COUNT=${#SELECTED_REGIONS[@]}

if [ $REGION_COUNT -eq 0 ]; then
    echo "❌ No valid regions selected. Exiting."
    exit 1
fi

echo "✅ Selected regions: ${SELECTED_REGIONS[*]}"
echo "📊 Total regions to audit: $REGION_COUNT"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS CLI not configured or no permissions. Please run 'aws configure' first."
    exit 1
fi

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
      max-width: 1400px;
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
    
    .service-section {
      background: rgba(248, 249, 250, 0.8);
      border-radius: 15px;
      padding: 25px;
      margin-bottom: 25px;
      border: 1px solid #e9ecef;
    }
    
    .service-header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 20px;
      padding-bottom: 15px;
      border-bottom: 2px solid #dee2e6;
    }
    
    .service-icon {
      font-size: 1.8rem;
    }
    
    .service-title {
      font-size: 1.5rem;
      font-weight: 700;
      color: #2c3e50;
      margin: 0;
    }
    
    .service-badge {
      background: #6c757d;
      color: white;
      padding: 4px 12px;
      border-radius: 15px;
      font-size: 0.8rem;
      font-weight: 600;
      margin-left: auto;
    }
    
    .checks-grid {
      display: grid;
      grid-template-columns: 1fr;
      gap: 15px;
    }
    
    .check-card {
      background: white;
      border-radius: 12px;
      padding: 20px;
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.08);
      border-left: 4px solid;
      transition: transform 0.3s ease, box-shadow 0.3s ease;
      display: flex;
      flex-direction: column;
      min-height: 200px;
    }
    
    .check-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 25px rgba(0, 0, 0, 0.12);
    }
    
    .check-card.ok { border-left-color: #27ae60; }
    .check-card.warn { border-left-color: #e67e22; }
    .check-card.error { border-left-color: #c0392b; }
    .check-card.info { border-left-color: #3498db; }
    
    .check-header {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 15px;
      flex-shrink: 0;
    }
    
    .check-icon {
      font-size: 1.3rem;
      width: 35px;
      height: 35px;
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
      border-radius: 8px;
      padding: 15px;
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
      font-size: 0.95rem;
      line-height: 1.5;
      flex-grow: 1;
      overflow-y: auto;
      border: 1px solid #e9ecef;
      min-height: 120px;
      max-height: 300px;
    }
    
    .status-badge {
      display: inline-block;
      padding: 6px 12px;
      border-radius: 15px;
      font-size: 0.85rem;
      font-weight: 600;
      margin-top: 12px;
      flex-shrink: 0;
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
      
      .stats-grid {
        grid-template-columns: repeat(2, 1fr);
      }
      
      .service-section {
        padding: 20px;
      }
      
      .service-title {
        font-size: 1.3rem;
      }
      
      .check-card {
        min-height: 180px;
        padding: 15px;
      }
      
      .check-content {
        min-height: 100px;
        font-size: 0.9rem;
        padding: 12px;
      }
    }
    
    /* Animation for cards */
    @keyframes fadeInUp {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    
    .service-section {
      animation: fadeInUp 0.6s ease forwards;
    }
    
    .service-section:nth-child(odd) {
      animation-delay: 0.1s;
    }
    
    .service-section:nth-child(even) {
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
echo "<div class='stat-label'>Regions Selected</div>"
echo "</div>"
echo "<div class='stat-card'>"
echo "<div class='stat-number'>27</div>"
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

# Global counters for summary
TOTAL_PASSED=0
TOTAL_WARNINGS=0
TOTAL_FAILED=0
TOTAL_ERRORS=0

run_check() {
    local TITLE="$1"
    local SCRIPT="$2"
    local ICON="$3"
    
    # Determine card class based on script output
    local CARD_CLASS="info"
    if [[ "$TITLE" == *"Error"* || "$TITLE" == *"Failed"* ]]; then
        CARD_CLASS="error"
    elif [[ "$TITLE" == *"Warn"* || "$TITLE" == *"Idle"* || "$TITLE" == *"Old"* ]]; then
        CARD_CLASS="warn"
    elif [[ "$TITLE" == *"Success"* || "$TITLE" == *"Completed"* ]]; then
        CARD_CLASS="ok"
    fi
    
    local OUTPUT=""
    local STATUS_BADGE=""
    
    if [ -f "$SCRIPT" ] && [ -x "$SCRIPT" ]; then
        OUTPUT=$(bash "$SCRIPT" 2>&1 | sed 's/</\&lt;/g; s/>/\&gt;/g')
    else
        OUTPUT="⚠️ Script not found or not executable: $SCRIPT"
    fi
    
    # Determine status badge and update counters
    if echo "$OUTPUT" | grep -q "✅\|Success\|Completed"; then
        STATUS_BADGE="<span class='status-badge status-ok'>✓ Passed</span>"
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    elif echo "$OUTPUT" | grep -q "⚠️\|Warning\|Idle\|Old"; then
        STATUS_BADGE="<span class='status-badge status-warn'>⚠️ Warning</span>"
        TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
    elif echo "$OUTPUT" | grep -q "❌\|Error\|Failed"; then
        STATUS_BADGE="<span class='status-badge status-error'>✗ Failed</span>"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    else
        STATUS_BADGE="<span class='status-badge status-ok'>ℹ️ Info</span>"
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    fi
    
    # Count script execution errors
    if echo "$OUTPUT" | grep -q "not found or not executable\|permission denied\|command not found"; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
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
REGION_CHECKS=27  # Updated number of checks per region

echo "🚀 Starting audit..."
echo "=============================================="

for REGION in "${SELECTED_REGIONS[@]}"; do
    REGION=$(echo "$REGION" | xargs)  # Trim whitespace
    REGIONS_SCANNED=$((REGIONS_SCANNED + 1))
    export AWS_DEFAULT_REGION="$REGION"
    
    echo "🔍 Processing region $REGIONS_SCANNED of $REGION_COUNT: $REGION"
    
    echo "<div class='region-section'>"
    echo "<div class='region-header'>"
    echo "<h2>🌍 Region: $REGION</h2>"
    echo "<div class='region-badge'>$REGION_CHECKS Checks</div>"
    echo "</div>"
    
    # EC2 & Compute Services Section
    echo "<div class='service-section'>"
    echo "<div class='service-header'>"
    echo "<div class='service-icon'>🖥️</div>"
    echo "<h3 class='service-title'>EC2 & Compute Services</h3>"
    echo "<div class='service-badge'>7 Checks</div>"
    echo "</div>"
    echo "<div class='checks-grid'>"
    run_check "Idle EC2 Instances" "./check_idle_ec2.sh" "🛌"
    run_check "Old AMIs" "./check_old_amis.sh" "🖼️"
    run_check "Unused AMIs" "./check_unused_amis.sh" "🔍"
    run_check "On-Demand Instances" "./check_on_demand_instances.sh" "💸"
    run_check "RI Utilization" "./check_reserved_instances.sh" "💰"
    run_check "EKS Clusters" "./check_eks_clusters.sh" "☸️"
    run_check "Cost Anomalies" "./check_cost_anomalies.sh" "📊"
    echo "</div>"
    echo "</div>"
    
    # Storage Services Section
    echo "<div class='service-section'>"
    echo "<div class='service-header'>"
    echo "<div class='service-icon'>💾</div>"
    echo "<h3 class='service-title'>Storage Services</h3>"
    echo "<div class='service-badge'>5 Checks</div>"
    echo "</div>"
    echo "<div class='checks-grid'>"
    run_check "EBS Snapshots" "./check_old_ebs_snapshots.sh" "💾"
    run_check "Orphaned Snapshots" "./check_orphaned_snapshots.sh" "🗑️"
    run_check "Unattached EBS" "./check_forgotten_ebs.sh" "🧹"
    run_check "S3 Lifecycle" "./check_s3_lifecycle.sh" "♻️"
    run_check "Backup Compliance" "./check_backup_compliance.sh" "💾"
    echo "</div>"
    echo "</div>"
    
    # Database Services Section
    echo "<div class='service-section'>"
    echo "<div class='service-header'>"
    echo "<div class='service-icon'>🗄️</div>"
    echo "<h3 class='service-title'>Database Services</h3>"
    echo "<div class='service-badge'>2 Checks</div>"
    echo "</div>"
    echo "<div class='checks-grid'>"
    run_check "RDS Snapshots" "./check_old_rds_snapshots.sh" "📅"
    run_check "Data Transfer" "./check_data_transfer_risks.sh" "🌐"
    echo "</div>"
    echo "</div>"
    
    # Networking Services Section
    echo "<div class='service-section'>"
    echo "<div class='service-header'>"
    echo "<div class='service-icon'>🌐</div>"
    echo "<h3 class='service-title'>Networking Services</h3>"
    echo "<div class='service-badge'>4 Checks</div>"
    echo "</div>"
    echo "<div class='checks-grid'>"
    run_check "Load Balancers" "./check_idle_load_balancers.sh" "🛑"
    run_check "Route 53 DNS" "./check_route53.sh" "🌍"
    run_check "Security Groups" "./check_security_groups.sh" "🛡️"
    run_check "Public Access Audit" "./check_public_access.sh" "🌐"
    echo "</div>"
    echo "</div>"
    
    # Security & Identity Section
    echo "<div class='service-section'>"
    echo "<div class='service-header'>"
    echo "<div class='service-icon'>🔐</div>"
    echo "<h3 class='service-title'>Security & Identity</h3>"
    echo "<div class='service-badge'>6 Checks</div>"
    echo "</div>"
    echo "<div class='checks-grid'>"
    run_check "IAM Usage" "./check_iam_usage.sh" "🔐"
    run_check "Encryption Audit" "./check_encryption.sh" "🔐"
    run_check "GuardDuty Findings" "./check_guardduty_findings.sh" "🛡️"
    run_check "AWS Config Rules" "./check_config_rules.sh" "⚙️"
    run_check "Compliance Standards" "./check_compliance_standards.sh" "📋"
    run_check "Logging & Monitoring" "./check_logging_monitoring.sh" "📝"
    echo "</div>"
    echo "</div>"
    
    # Monitoring & Governance Section
    echo "<div class='service-section'>"
    echo "<div class='service-header'>"
    echo "<div class='service-icon'>📈</div>"
    echo "<h3 class='service-title'>Monitoring & Governance</h3>"
    echo "<div class='service-badge'>3 Checks</div>"
    echo "</div>"
    echo "<div class='checks-grid'>"
    run_check "Budget Alerts" "./check_budgets.sh" "💰"
    run_check "CloudWatch Alarms" "./check_cloudwatch_alarms.sh" "📈"
    run_check "Resource Tagging" "./check_untagged_resources.sh" "🏷️"
    echo "</div>"
    echo "</div>"
    
    echo "<div style='text-align: center; margin-top: 20px;'>"
    echo "<div class='status-badge status-ok'>✅ Audit Completed for $REGION</div>"
    echo "</div>"
    echo "</div>" # closes region-section
    
    echo "✅ Completed region: $REGION"
    echo "----------------------------------------------"
done

# Calculate totals
TOTAL_CHECKS=$((REGIONS_SCANNED * REGION_CHECKS))
TOTAL_EXECUTED=$((TOTAL_PASSED + TOTAL_WARNINGS + TOTAL_FAILED))

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
echo "<p><strong>Total Checks:</strong> $TOTAL_CHECKS</p>"
echo "<p><strong>Checks Executed:</strong> $TOTAL_EXECUTED</p>"
echo "<div style='display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin: 20px 0;'>"
echo "<div style='background: #d5f4e6; padding: 10px; border-radius: 8px;'><strong>✅ Passed:</strong> $TOTAL_PASSED</div>"
echo "<div style='background: #fdebd0; padding: 10px; border-radius: 8px;'><strong>⚠️ Warnings:</strong> $TOTAL_WARNINGS</div>"
echo "<div style='background: #fadbd8; padding: 10px; border-radius: 8px;'><strong>❌ Failed:</strong> $TOTAL_FAILED</div>"
echo "<div style='background: #f2f3f4; padding: 10px; border-radius: 8px;'><strong>🔧 Errors:</strong> $TOTAL_ERRORS</div>"
echo "</div>"
echo "<p class='timestamp'>Report generated on: $(date +'%d-%b-%Y at %H:%M:%S %Z')</p>"
echo "<div style='margin-top: 30px; padding: 20px; background: #f8f9fa; border-radius: 10px; text-align: center;'>"
echo "<h4 style='color: #2c3e50; margin-bottom: 15px;'>🔗 Project Links & Resources</h4>"
echo "<div style='display: flex; justify-content: center; gap: 20px; flex-wrap: wrap;'>"
echo "<a href='https://github.com/harishnshetty/AWS-idle-resource-finder-project.git' target='_blank' style='display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; background: #333; color: white; text-decoration: none; border-radius: 25px; font-weight: 600; transition: transform 0.3s ease;'>"
echo "<svg width='20' height='20' viewBox='0 0 24 24' fill='currentColor'><path d='M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z'/></svg>"
echo "GitHub Repository"
echo "</a>"
echo "<a href='https://harishnshetty.github.io/projects.html' target='_blank' style='display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; background: #0073bb; color: white; text-decoration: none; border-radius: 25px; font-weight: 600; transition: transform 0.3s ease;'>"
echo "<svg width='20' height='20' viewBox='0 0 24 24' fill='currentColor'><path d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z'/></svg>"
echo "Project Portfolio"
echo "</a>"
echo "<a href='https://www.youtube.com/@devopsHarishNShetty' target='_blank' style='display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; background: #ff0000; color: white; text-decoration: none; border-radius: 25px; font-weight: 600; transition: transform 0.3s ease;'>"
echo "<svg width='20' height='20' viewBox='0 0 24 24' fill='currentColor'><path d='M19.615 3.184c-3.604-.246-11.631-.245-15.23 0-3.897.266-4.356 2.62-4.385 8.816.029 6.185.484 8.549 4.385 8.816 3.6.245 11.626.246 15.23 0 3.897-.266 4.356-2.62 4.385-8.816-.029-6.185-.484-8.549-4.385-8.816zm-10.615 12.816v-8l8 3.993-8 4.007z'/></svg>"
echo "YouTube Channel"
echo "</a>"
echo "</div>"
echo "<p style='margin-top: 15px; color: #666; font-size: 0.9rem;'>Made with ❤️ by Harish N Shetty | DevOps Engineer</p>"
echo "</div>"
echo "</div>"


echo "</div>" # closes app-container
echo "</body></html>"
} | tee "${HTML_REPORT}"

echo "=============================================="
echo "🎉 AWS Audit Completed Successfully!"
echo "📊 Summary:"
echo "   ✅ Regions scanned: $REGIONS_SCANNED"
echo "   📋 Total checks: $TOTAL_CHECKS"
echo "   ✅ Passed: $TOTAL_PASSED"
echo "   ⚠️  Warnings: $TOTAL_WARNINGS"
echo "   ❌ Failed: $TOTAL_FAILED"
echo "   🔧 Errors: $TOTAL_ERRORS"
echo "📄 HTML report saved to: $HTML_REPORT"
echo "🌐 Open it in a browser to view detailed results"
echo "=============================================="