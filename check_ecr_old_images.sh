#!/bin/bash
# check_ecr_old_images.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
DAYS_THRESHOLD=90

echo "🔍 Checking for old ECR images in $REGION (>$DAYS_THRESHOLD days)"

TOTAL_REPOS=0
TOTAL_IMAGES=0
OLD_IMAGES=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Get list of ECR repositories
if ! REPOS=$(aws ecr describe-repositories --region "$REGION" --query 'repositories[].repositoryName' --output text 2>/dev/null); then
    echo "❌ No permission to access ECR or no repositories found"
    exit 0
fi

if [ -z "$REPOS" ] || [ "$REPOS" == "None" ]; then
    echo "✅ No ECR repositories found in region $REGION"
    exit 0
fi

for REPO in $REPOS; do
    TOTAL_REPOS=$((TOTAL_REPOS + 1))
    echo ""
    echo "📦 Repository: $REPO"
    
    # Get image details
    if IMAGES=$(aws ecr describe-images \
        --repository-name "$REPO" \
        --region "$REGION" \
        --query 'imageDetails[?imageTags!=null] | sort_by(@, &imagePushedAt)[].{Tags: imageTags[0], PushedAt: imagePushedAt}' \
        --output json 2>/dev/null); then
        
        IMAGE_COUNT=$(echo "$IMAGES" | jq -r 'length')
        TOTAL_IMAGES=$((TOTAL_IMAGES + IMAGE_COUNT))
        
        if [ "$IMAGE_COUNT" -eq 0 ]; then
            echo "   ℹ️  No tagged images found"
            continue
        fi
        
        # Check each image
        echo "$IMAGES" | jq -c '.[]' | while read -r IMAGE; do
            TAG=$(echo "$IMAGE" | jq -r '.Tags')
            PUSHED_AT=$(echo "$IMAGE" | jq -r '.PushedAt')
            
            # Convert to timestamp
            PUSHED_TS=$(date -d "$PUSHED_AT" +%s 2>/dev/null || echo "0")
            CURRENT_TS=$(date +%s)
            
            if [ "$PUSHED_TS" -ne 0 ]; then
                AGE_DAYS=$(( (CURRENT_TS - PUSHED_TS) / 86400 ))
                
                if [ "$AGE_DAYS" -gt "$DAYS_THRESHOLD" ]; then
                    echo "    ⚠️  OLD: $TAG (${AGE_DAYS} days old)"
                    OLD_IMAGES=$((OLD_IMAGES + 1))
                else
                    echo "    ✅ Recent: $TAG (${AGE_DAYS} days old)"
                fi
            fi
        done
    else
        echo "   ❌ Unable to list images"
    fi
done

echo ""
echo "📈 Summary:"
echo "   Total repositories: $TOTAL_REPOS"
echo "   Total images: $TOTAL_IMAGES"
echo "   Old images (>$DAYS_THRESHOLD days): $OLD_IMAGES"

if [ "$OLD_IMAGES" -gt 0 ]; then
    echo "⚠️  Recommendation: Consider deleting old unused images to reduce storage costs"
fi