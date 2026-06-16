#!/bin/bash
# Monitor GitHub Actions workflow run status

REPO="00660/pine-art-hotupdate-public-20260615-162321"
RUN_ID="${1}"

# Get GitHub token
TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>&1 | grep '^password=' | cut -d= -f2)

if [ -z "$TOKEN" ]; then
    echo "ERROR: Unable to get GitHub token"
    exit 1
fi

# If no run ID provided, get the latest
if [ -z "$RUN_ID" ]; then
    echo "Fetching latest workflow run..."
    RUN_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
                    -H "Accept: application/vnd.github+json" \
                    "https://api.github.com/repos/$REPO/actions/runs?per_page=1" | \
             grep -m1 '"id":' | grep -o '[0-9]\+')

    if [ -z "$RUN_ID" ]; then
        echo "ERROR: Could not find any workflow runs"
        exit 1
    fi
    echo "Monitoring run ID: $RUN_ID"
fi

echo "========================================"
echo "Pine ART Hot Update Build Monitor"
echo "========================================"
echo "Repository: $REPO"
echo "Run ID: $RUN_ID"
echo "========================================"
echo ""

# Monitor loop
LAST_STATUS=""
while true; do
    # Fetch run status
    RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
                      -H "Accept: application/vnd.github+json" \
                      "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID")

    STATUS=$(echo "$RESPONSE" | grep -m1 '"status":' | sed 's/.*"status": *"\([^"]*\)".*/\1/')
    CONCLUSION=$(echo "$RESPONSE" | grep -m1 '"conclusion":' | sed 's/.*"conclusion": *"\([^"]*\)".*/\1/' | grep -v "null")
    CREATED_AT=$(echo "$RESPONSE" | grep -m1 '"created_at":' | sed 's/.*"created_at": *"\([^"]*\)".*/\1/')
    UPDATED_AT=$(echo "$RESPONSE" | grep -m1 '"updated_at":' | sed 's/.*"updated_at": *"\([^"]*\)".*/\1/')
    HTML_URL=$(echo "$RESPONSE" | grep -m1 '"html_url":' | sed 's/.*"html_url": *"\([^"]*\)".*/\1/')

    # Only print if status changed
    if [ "$STATUS" != "$LAST_STATUS" ]; then
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$TIMESTAMP] Status: $STATUS"

        if [ -n "$CONCLUSION" ]; then
            if [ "$CONCLUSION" = "success" ]; then
                echo "✅ Build completed successfully!"
                echo ""
                echo "Download artifact:"
                echo "  gh run download $RUN_ID --repo $REPO --name pine-art-hotupdate"
                echo ""
                echo "Or visit:"
                echo "  $HTML_URL"
                exit 0
            else
                echo "❌ Build failed with conclusion: $CONCLUSION"
                echo ""
                echo "Check logs:"
                echo "  $HTML_URL"
                exit 1
            fi
        fi

        LAST_STATUS="$STATUS"
    fi

    # Wait before next check
    sleep 30
done
