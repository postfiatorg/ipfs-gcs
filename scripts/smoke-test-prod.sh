#!/bin/bash
set -e

echo "🧪 Running smoke tests for production environment..."

# Get production URL
PROD_URL=$(bash scripts/get-prod-url.sh | grep "✅ Production URL:" | sed 's/.*: //')

if [ -z "$PROD_URL" ]; then
    echo "❌ Could not get production URL. Is the production environment deployed?"
    exit 1
fi

echo "🌐 Testing production at: $PROD_URL"
echo ""

# Test 1: Health check
echo "🔍 Test 1: Health check"
if curl -s -f "$PROD_URL/health" > /dev/null; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Test 2: Upload a small test file
echo "🔍 Test 2: File upload"
TEST_FILE=$(mktemp)
echo "Hello from production smoke test at $(date)" > "$TEST_FILE"

UPLOAD_RESPONSE=$(curl -s -F "upload=@$TEST_FILE" "$PROD_URL/upload")
if echo "$UPLOAD_RESPONSE" | grep -q "ipfs"; then
    IPFS_HASH=$(echo "$UPLOAD_RESPONSE" | grep -o 'ipfs/[A-Za-z0-9]*' | head -1)
    echo "✅ File uploaded successfully: $IPFS_HASH"
else
    echo "❌ File upload failed"
    echo "Response: $UPLOAD_RESPONSE"
    rm "$TEST_FILE"
    exit 1
fi

# Test 3: Download the uploaded file
echo "🔍 Test 3: File download"
DOWNLOAD_URL="$PROD_URL/download/$IPFS_HASH"
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
echo "🎉 All production smoke tests passed!"
echo "✅ Production environment is working correctly"