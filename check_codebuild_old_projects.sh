#!/bin/bash
# check_codebuild_old_projects.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
DAYS_THRESHOLD=90

echo "🔍 Checking for old/unused CodeBuild projects (>$DAYS_THRESHOLD days) in $REGION"

TOTAL_PROJECTS=0
OLD_PROJECTS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# List CodeBuild projects
if ! PROJECTS=$(aws codebuild list-projects --region "$REGION" --query 'projects' --output text 2>/dev/null); then
    echo "❌ No permission to list CodeBuild projects"
    exit 0
fi

if [ -z "$PROJECTS" ] || [ "$PROJECTS" == "None" ]; then
    echo "✅ No CodeBuild projects found in region $REGION"
    exit 0
fi

for PROJECT_NAME in $PROJECTS; do
    TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))
    
    echo "🏗️ Project: $PROJECT_NAME"
    
    # Get build history
    if BUILDS=$(aws codebuild list-builds-for-project --project-name "$PROJECT_NAME" --region "$REGION" --query 'ids[0]' --output text 2>/dev/null); then
        if [ -n "$BUILDS" ] && [ "$BUILDS" != "None" ]; then
            # Get details of most recent build
            if BUILD_DETAILS=$(aws codebuild batch-get-builds --ids "$BUILDS" --region "$REGION" --query 'builds[0]' --output json 2>/dev/null); then
                LAST_BUILD_TIME=$(echo "$BUILD_DETAILS" | jq -r '.endTime // .startTime // .queuedTime')
                BUILD_STATUS=$(echo "$BUILD_DETAILS" | jq -r '.buildStatus')
                
                if [ "$LAST_BUILD_TIME" != "null" ]; then
                    LAST_TS=$(date -d "$LAST_BUILD_TIME" +%s 2>/dev/null || echo 0)
                    CURRENT_TS=$(date +%s)
                    DAYS_SINCE_BUILD=$(( (CURRENT_TS - LAST_TS) / 86400 ))
                    
                    echo "   Last build: $LAST_BUILD_TIME ($DAYS_SINCE_BUILD days ago)"
                    echo "   Status: $BUILD_STATUS"
                    
                    if [ "$DAYS_SINCE_BUILD" -gt "$DAYS_THRESHOLD" ]; then
                        echo "   ⚠️  OLD: No recent builds in $DAYS_SINCE_BUILD days"
                        OLD_PROJECTS=$((OLD_PROJECTS + 1))
                    else
                        echo "   ✅ Recently used"
                    fi
                else
                    echo "   ℹ️  No build history found"
                fi
            else
                echo "   ℹ️  Unable to get build details"
            fi
        else
            echo "   ℹ️  No builds found for project"
            OLD_PROJECTS=$((OLD_PROJECTS + 1))
        fi
    else
        echo "   ❌ Unable to get build history"
    fi
    echo ""
done

echo "📈 Summary:"
echo "   Total CodeBuild projects: $TOTAL_PROJECTS"
echo "   Old/unused projects: $OLD_PROJECTS"

if [ "$OLD_PROJECTS" -gt 0 ]; then
    echo "⚠️  Recommendation: Consider removing old CodeBuild projects that are no longer used"
fi