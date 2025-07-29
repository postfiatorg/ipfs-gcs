#!/bin/bash
set -e

echo "🧪 Running smoke tests for staging environment..."

# Get staging URL
STAGING_URL=$(bash scripts/get-staging-url.sh | grep "✅ Staging URL:" | sed 's/.*: //')

if [ -z "$STAGING_URL" ]; then
    echo "❌ Could not get staging URL. Is the staging environment deployed?"
    exit 1
fi

echo "🌐 Testing staging at: $STAGING_URL"
echo ""

# Test 1: Health check
echo "🔍 Test 1: Health check"
if curl -s -f "$STAGING_URL/health" > /dev/null; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Test 2: Upload a small test file
echo "🔍 Test 2: File upload"
TEST_FILE=$(mktemp)
echo "Hello from staging smoke test at $(date)" > "$TEST_FILE"

UPLOAD_RESPONSE=$(curl -s -F "upload=@$TEST_FILE" "$STAGING_URL/upload")
if echo "$UPLOAD_RESPONSE" | grep -q "hash"; then
    IPFS_HASH=$(echo "$UPLOAD_RESPONSE" | jq -r .hash)
    echo "✅ File uploaded successfully: $IPFS_HASH"
else
    echo "❌ File upload failed"
    echo "Response: $UPLOAD_RESPONSE"
    rm "$TEST_FILE"
    exit 1
fi

# Test 3: Download the uploaded file
echo "🔍 Test 3: File download"
DOWNLOAD_URL="$STAGING_URL/download/ipfs/$IPFS_HASH"
DOWNLOADED_CONTENT=$(curl -s "$DOWNLOAD_URL")

if [ -n "$DOWNLOADED_CONTENT" ]; then
    echo "✅ File download successful"
    echo "   Content preview: $(echo "$DOWNLOADED_CONTENT" | head -c 50)..."
else
    echo "❌ File download failed"
    rm "$TEST_FILE"
    exit 1
fi

# Test 4: Verify content matches
echo "🔍 Test 4: Content verification"
ORIGINAL_CONTENT=$(cat "$TEST_FILE")
if [ "$ORIGINAL_CONTENT" = "$DOWNLOADED_CONTENT" ]; then
    echo "✅ Content verification passed"
else
    echo "❌ Content verification failed"
    echo "   Original: $ORIGINAL_CONTENT"
    echo "   Downloaded: $DOWNLOADED_CONTENT"
    rm "$TEST_FILE"
    exit 1
fi

# Cleanup
rm "$TEST_FILE"

echo ""
echo "🎉 All staging smoke tests passed!"
echo "✅ Staging environment is working correctly"