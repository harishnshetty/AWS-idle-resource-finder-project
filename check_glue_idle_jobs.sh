#!/bin/bash
# check_glue_idle_jobs.sh
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
DAYS_THRESHOLD=30

echo "🔍 Checking for idle Glue jobs/crawlers (>$DAYS_THRESHOLD days inactive) in $REGION"

TOTAL_JOBS=0
IDLE_JOBS=0
TOTAL_CRAWLERS=0
IDLE_CRAWLERS=0

if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
fi

# Check Glue Jobs
echo "🛠️ Glue Jobs:"
if JOBS=$(aws glue get-jobs --region "$REGION" --query 'Jobs[].Name' --output text 2>/dev/null); then
    for JOB_NAME in $JOBS; do
        TOTAL_JOBS=$((TOTAL_JOBS + 1))
        
        # Get job runs
        if RUNS=$(aws glue get-job-runs --job-name "$JOB_NAME" --region "$REGION" --query 'JobRuns[].CompletedOn' --output text 2>/dev/null); then
            LATEST_RUN=$(echo "$RUNS" | tr '\t' '\n' | sort -r | head -1)
            
            if [ -n "$LATEST_RUN" ]; then
                LATEST_TS=$(date -d "$LATEST_RUN" +%s 2>/dev/null || echo 0)
                CURRENT_TS=$(date +%s)
                DAYS_SINCE_RUN=$(( (CURRENT_TS - LATEST_TS) / 86400 ))
                
                echo "  - $JOB_NAME"
                echo "    Last run: $LATEST_RUN ($DAYS_SINCE_RUN days ago)"
                
                if [ "$DAYS_SINCE_RUN" -gt "$DAYS_THRESHOLD" ]; then
                    echo "    ⚠️  IDLE: No runs in $DAYS_SINCE_RUN days"
                    IDLE_JOBS=$((IDLE_JOBS + 1))
                else
                    echo "    ✅ Active"
                fi
            fi
        else
            echo "  - $JOB_NAME: Unable to get run history"
        fi
    done
else
    echo "  ℹ️ No Glue jobs found or no permissions"
fi

# Check Glue Crawlers
echo ""
echo "🕷️ Glue Crawlers:"
if CRAWLERS=$(aws glue get-crawlers --region "$REGION" --query 'Crawlers[]' --output json 2>/dev/null); then
    echo "$CRAWLERS" | jq -c '.[]' | while read -r CRAWLER; do
        TOTAL_CRAWLERS=$((TOTAL_CRAWLERS + 1))
        CRAWLER_NAME=$(echo "$CRAWLER" | jq -r '.Name')
        STATE=$(echo "$CRAWLER" | jq -r '.State')
        LAST_CRAWL=$(echo "$CRAWLER" | jq -r '.LastCrawl.LastModifiedOn // empty')
        
        echo "  - $CRAWLER_NAME"
        echo "    State: $STATE"
        
        if [ -n "$LAST_CRAWL" ]; then
            LAST_TS=$(date -d "$LAST_CRAWL" +%s 2>/dev/null || echo 0)
            CURRENT_TS=$(date +%s)
            DAYS_SINCE_CRAWL=$(( (CURRENT_TS - LAST_TS) / 86400 ))
            
            echo "    Last crawl: $LAST_CRAWL ($DAYS_SINCE_CRAWL days ago)"
            
            if [ "$DAYS_SINCE_CRAWL" -gt "$DAYS_THRESHOLD" ] && [ "$STATE" != "RUNNING" ]; then
                echo "    ⚠️  IDLE: No crawls in $DAYS_SINCE_CRAWL days"
                IDLE_CRAWLERS=$((IDLE_CRAWLERS + 1))
            else
                echo "    ✅ Active"
            fi
        else
            echo "    ℹ️  No crawl history"
        fi
    done
else
    echo "  ℹ️ No Glue crawlers found or no permissions"
fi

echo ""
echo "📈 Summary:"
echo "   Total Glue jobs: $TOTAL_JOBS"
echo "   Idle jobs: $IDLE_JOBS"
echo "   Total Glue crawlers: $TOTAL_CRAWLERS"
echo "   Idle crawlers: $IDLE_CRAWLERS"

if [ $((IDLE_JOBS + IDLE_CRAWLERS)) -gt 0 ]; then
    echo "⚠️  Recommendation: Consider removing or disabling idle Glue jobs/crawlers"
fi