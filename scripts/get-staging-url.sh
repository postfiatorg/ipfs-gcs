#!/bin/bash
set -e

echo "🔍 Getting staging environment URL..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if gcloud is available and try to get cluster credentials
if command -v gcloud &> /dev/null; then
    if [ -n "$GCP_PROJECT_ID" ]; then
        echo "🔧 Getting cluster credentials..."
        gcloud container clusters get-credentials ipfs-gcs-staging --zone us-central1-a --project $GCP_PROJECT_ID 2>/dev/null || echo "⚠️  Could not get credentials, assuming already configured"
    else
        echo "⚠️  GCP_PROJECT_ID not set, assuming kubectl is already configured"
    fi
fi

# Get external IP from staging service
echo "🌐 Looking for staging service external IP..."
EXTERNAL_IP=$(kubectl get svc ipfs-gcs -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
    STAGING_URL="http://$EXTERNAL_IP"
    echo "✅ Staging URL: $STAGING_URL"
    echo ""
    echo "🧪 Quick test:"
    curl -s "$STAGING_URL/health" && echo " ✅ Health check passed" || echo " ❌ Health check failed"
    echo ""
    echo "📋 Available endpoints:"
    echo "   • Health: $STAGING_URL/health"
    echo "   • Upload: curl -F \"upload=@file.txt\" $STAGING_URL/upload"
    echo "   • Download: $STAGING_URL/download/ipfs/[hash]"
else
    echo "⏳ External IP not ready yet. Checking service status..."
    kubectl get svc ipfs-gcs -n staging 2>/dev/null || echo "❌ Staging service not found. Is the application deployed?"
    echo ""
    echo "💡 If the service was just deployed, it may take a few minutes for the external IP to be assigned."
    echo "   Run this script again in a few minutes."
fi