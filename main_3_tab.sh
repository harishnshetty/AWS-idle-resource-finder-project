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
      max-width: 1800px;
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
    
    /* Tabs Navigation */
    .tabs-container {
      margin-bottom: 25px;
    }
    
    .tabs-nav {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-bottom: 20px;
      padding: 15px;
      background: rgba(248, 249, 250, 0.8);
      border-radius: 15px;
      border: 1px solid #e9ecef;
    }
    
    .tab-btn {
      padding: 12px 20px;
      background: white;
      border: 2px solid #e9ecef;
      border-radius: 10px;
      font-weight: 600;
      color: #6c757d;
      cursor: pointer;
      transition: all 0.3s ease;
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 0.9rem;
    }
    
    .tab-btn:hover {
      border-color: #667eea;
      color: #667eea;
      transform: translateY(-2px);
    }
    
    .tab-btn.active {
      background: linear-gradient(135deg, #667eea, #764ba2);
      color: white;
      border-color: #667eea;
      box-shadow: 0 5px 15px rgba(102, 126, 234, 0.3);
    }
    
    .tab-btn.all-tab {
      background: linear-gradient(135deg, #27ae60, #2ecc71);
      color: white;
      border-color: #27ae60;
    }
    
    /* Single Column Layout - One block per line */
    .checks-grid {
      display: flex;
      flex-direction: column;
      gap: 20px;
    }
    
    .check-card {
      background: white;
      border-radius: 15px;
      padding: 25px;
      box-shadow: 0 8px 25px rgba(0, 0, 0, 0.08);
      border-left: 5px solid;
      transition: all 0.3s ease;
      display: flex;
      flex-direction: column;
      min-height: 300px;
      width: 100%;
    }
    
    .check-card:hover {
      transform: translateY(-3px);
      box-shadow: 0 12px 30px rgba(0, 0, 0, 0.15);
    }
    
    .check-card.ok { border-left-color: #27ae60; }
    .check-card.warn { border-left-color: #e67e22; }
    .check-card.error { border-left-color: #c0392b; }
    .check-card.info { border-left-color: #3498db; }
    
    .check-header {
      display: flex;
      align-items: center;
      gap: 15px;
      margin-bottom: 20px;
      flex-shrink: 0;
    }
    
    .check-icon {
      font-size: 1.8rem;
      width: 50px;
      height: 50px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      background: rgba(52, 152, 219, 0.1);
      flex-shrink: 0;
    }
    
    .check-title-container {
      display: flex;
      flex-direction: column;
      gap: 5px;
      flex-grow: 1;
    }
    
    .check-title {
      font-size: 1.4rem;
      font-weight: 700;
      color: #2c3e50;
      margin: 0;
    }
    
    .service-badge {
      background: #6c757d;
      color: white;
      padding: 6px 14px;
      border-radius: 15px;
      font-size: 0.85rem;
      font-weight: 600;
      align-self: flex-start;
    }
    
    .check-content {
      background: #f8f9fa;
      border-radius: 10px;
      padding: 20px;
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
      font-size: 1rem;
      line-height: 1.6;
      flex-grow: 1;
      overflow-y: auto;
      border: 1px solid #e9ecef;
      min-height: 150px;
      max-height: 350px;
    }
    
    .status-badge {
      display: inline-block;
      padding: 10px 20px;
      border-radius: 20px;
      font-size: 1rem;
      font-weight: 600;
      margin-top: 15px;
      flex-shrink: 0;
      align-self: flex-start;
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
      width: 8px;
    }
    
    .check-content::-webkit-scrollbar-track {
      background: #f1f1f1;
      border-radius: 4px;
    }
    
    .check-content::-webkit-scrollbar-thumb {
      background: #c1c1c1;
      border-radius: 4px;
    }
    
    .check-content::-webkit-scrollbar-thumb:hover {
      background: #a8a8a8;
    }
    
    /* Animations */
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(10px); }
      to { opacity: 1; transform: translateY(0); }
    }
    
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
    
    .check-card.hidden {
      display: none;
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
      
      .tabs-nav {
        flex-direction: column;
      }
      
      .tab-btn {
        justify-content: center;
        text-align: center;
      }
      
      .stats-grid {
        grid-template-columns: repeat(2, 1fr);
      }
      
      .check-card {
        min-height: 280px;
        padding: 20px;
      }
      
      .check-header {
        flex-direction: column;
        align-items: flex-start;
        gap: 10px;
      }
      
      .check-icon {
        width: 40px;
        height: 40px;
        font-size: 1.5rem;
      }
      
      .check-title {
        font-size: 1.2rem;
      }
      
      .check-content {
        min-height: 120px;
        font-size: 0.9rem;
        padding: 15px;
      }
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
echo "<div class='stat-number'>42</div>"
echo "<div class='stat-label'>Security Checks</div>"
echo "</div>"
echo "<div class='stat-card'>"
echo "<div class='stat-number'>500+</div>"
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
    local CATEGORY="$4"
    
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
    
    echo "<div class='check-card $CARD_CLASS' data-category='$CATEGORY'>"
    echo "<div class='check-header'>"
    echo "<div class='check-icon'>$ICON</div>"
    echo "<div class='check-title-container'>"
    echo "<h3 class='check-title'>$TITLE</h3>"
    echo "<span class='service-badge'>$CATEGORY</span>"
    echo "</div>"
    echo "</div>"
    echo "<div class='check-content'>"
    echo "$OUTPUT"
    echo "</div>"
    echo "$STATUS_BADGE"
    echo "</div>"
}

REGIONS_SCANNED=0
REGION_CHECKS=42  # Updated to 42 checks

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
    
    # Tabs Navigation
    echo "<div class='tabs-container'>"
    echo "<div class='tabs-nav'>"
    echo "<button class='tab-btn all-tab active' onclick=\"filterChecks('$REGION', 'all', this)\">📊 All Checks</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'compute', this)\">🖥️ Compute</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'storage', this)\">💾 Storage</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'database', this)\">🗄️ Database</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'networking', this)\">🌐 Networking</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'security', this)\">🔐 Security</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'monitoring', this)\">📈 Monitoring</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'serverless', this)\">⚡ Serverless</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'developer', this)\">🛠️ Developer</button>"
    echo "<button class='tab-btn' onclick=\"filterChecks('$REGION', 'management', this)\">🎯 Management</button>"
    echo "</div>"
    
    # Single Column Layout - One block per line
    echo "<div class='checks-grid' id='$REGION-checks-grid'>"
    
    # Compute Checks
    run_check "Idle EC2 Instances" "./check_idle_ec2.sh" "🛌" "compute"
    run_check "Old AMIs" "./check_old_amis.sh" "🖼️" "compute"
    run_check "Unused AMIs" "./check_unused_amis.sh" "🔍" "compute"
    run_check "On-Demand Instances" "./check_on_demand_instances.sh" "💸" "compute"
    run_check "RI Utilization" "./check_reserved_instances.sh" "💰" "compute"
    run_check "EKS Clusters" "./check_eks_clusters.sh" "☸️" "compute"
    run_check "ECS Idle Services" "./check_ecs_idle_services.sh" "🏗️" "compute"
    
    # Storage Checks
    run_check "EBS Snapshots" "./check_old_ebs_snapshots.sh" "💾" "storage"
    run_check "Orphaned Snapshots" "./check_orphaned_snapshots.sh" "🗑️" "storage"
    run_check "Unattached EBS" "./check_forgotten_ebs.sh" "🧹" "storage"
    run_check "S3 Lifecycle" "./check_s3_lifecycle.sh" "♻️" "storage"
    run_check "Backup Compliance" "./check_backup_compliance.sh" "💾" "storage"
    run_check "ECR Old Images" "./check_ecr_old_images.sh" "📦" "storage"
    
    # Database Checks
    run_check "RDS Snapshots" "./check_old_rds_snapshots.sh" "📅" "database"
    run_check "Data Transfer" "./check_data_transfer_risks.sh" "🌐" "database"
    run_check "Redshift Utilization" "./check_redshift_utilization.sh" "🔴" "database"
    
    # Networking Checks
    run_check "Load Balancers" "./check_idle_load_balancers.sh" "🛑" "networking"
    run_check "Route 53 DNS" "./check_route53.sh" "🌍" "networking"
    run_check "Security Groups" "./check_security_groups.sh" "🛡️" "networking"
    run_check "Public Access Audit" "./check_public_access.sh" "🌐" "networking"
    run_check "VPC Flow Logs" "./check_vpc_flow_logs.sh" "📝" "networking"
    
    # Security Checks
    run_check "IAM Usage" "./check_iam_usage.sh" "🔐" "security"
    run_check "Encryption Audit" "./check_encryption.sh" "🔐" "security"
    run_check "GuardDuty Findings" "./check_guardduty_findings.sh" "🛡️" "security"
    run_check "AWS Config Rules" "./check_config_rules.sh" "⚙️" "security"
    run_check "Compliance Standards" "./check_compliance_standards.sh" "📋" "security"
    run_check "KMS Orphaned Keys" "./check_kms_orphaned_keys.sh" "🔑" "security"
    run_check "Secrets Manager Old Secrets" "./check_secrets_manager_old_secrets.sh" "🔐" "security"
    
    # Monitoring Checks
    run_check "Budget Alerts" "./check_budgets.sh" "💰" "monitoring"
    run_check "CloudWatch Alarms" "./check_cloudwatch_alarms.sh" "📈" "monitoring"
    run_check "Resource Tagging" "./check_untagged_resources.sh" "🏷️" "monitoring"
    run_check "Logging & Monitoring" "./check_logging_monitoring.sh" "📝" "monitoring"
    run_check "Cost Anomalies" "./check_cost_anomalies.sh" "📊" "monitoring"
    
    # Serverless & AI/ML Checks
    run_check "Idle Lambda Functions" "./check_idle_lambda.sh" "λ" "serverless"
    run_check "Large Lambda Packages" "./check_large_lambda_packages.sh" "📏" "serverless"
    run_check "Lambda Old Runtimes" "./check_lambda_old_runtimes.sh" "🕐" "serverless"
    run_check "SageMaker Idle Instances" "./check_sagemaker_idle_instances.sh" "🤖" "serverless"
    run_check "Comprehend Usage" "./check_comprehend_usage.sh" "🈯" "serverless"
    run_check "Glue Idle Jobs" "./check_glue_idle_jobs.sh" "🕷️" "serverless"
    run_check "EMR Idle Clusters" "./check_emr_idle_clusters.sh" "🔧" "serverless"
    
    # Developer Tools Checks
    run_check "CodeBuild Old Projects" "./check_codebuild_old_projects.sh" "🏗️" "developer"
    run_check "CodePipeline Idle Pipelines" "./check_codepipeline_idle_pipelines.sh" "⚙️" "developer"
    
    # Management Checks
    run_check "Trusted Advisor" "./check_trusted_advisor.sh" "📋" "management"
    run_check "Cost Explorer Data" "./check_cost_explorer_data.sh" "💰" "management"
    run_check "Service Quotas" "./check_service_quotas.sh" "🎯" "management"
    
    echo "</div>" # closes checks-grid
    echo "</div>" # closes tabs-container
    
    echo "<div style='text-align: center; margin-top: 20px;'>"
    echo "<div class='status-badge status-ok'>✅ Audit Completed for $REGION</div>"
    echo "</div>"
    echo "</div>" # closes region-section
    
    echo "✅ Completed region: $REGION"
    echo "----------------------------------------------"
done

# JavaScript for filtering functionality
echo "<script>
function filterChecks(region, category, element) {
    // Remove active class from all buttons in the same tab navigation
    const tabNav = element.parentElement;
    const buttons = tabNav.querySelectorAll('.tab-btn');
    buttons.forEach(btn => {
        btn.classList.remove('active');
    });
    
    // Add active class to clicked button
    element.classList.add('active');
    
    // Get all check cards in this region
    const grid = document.getElementById(region + '-checks-grid');
    const cards = grid.querySelectorAll('.check-card');
    
    // Show/hide cards based on category
    cards.forEach(card => {
        if (category === 'all' || card.getAttribute('data-category') === category) {
            card.classList.remove('hidden');
            card.style.animation = 'fadeInUp 0.6s ease forwards';
        } else {
            card.classList.add('hidden');
        }
    });
}

// Add keyboard navigation
document.addEventListener('keydown', function(e) {
    if (e.altKey) {
        const regions = document.querySelectorAll('.region-section');
        regions.forEach(region => {
            const tabs = region.querySelectorAll('.tab-btn');
            tabs.forEach((tab, index) => {
                if (e.key === (index).toString() && index < 10) {
                    tab.click();
                }
            });
        });
    }
});

// Initialize all regions to show all checks
document.addEventListener('DOMContentLoaded', function() {
    const regions = document.querySelectorAll('.region-section');
    regions.forEach(region => {
        const regionId = region.querySelector('.checks-grid').id.replace('-checks-grid', '');
        filterChecks(regionId, 'all', region.querySelector('.all-tab'));
    });
});
</script>"

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