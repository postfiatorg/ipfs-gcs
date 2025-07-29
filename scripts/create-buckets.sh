#!/bin/bash
set -e

# Script to create GCS buckets for staging and production environments

# Check if GCP_PROJECT_ID is set
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ Error: GCP_PROJECT_ID environment variable is not set"
    echo "Please run: export GCP_PROJECT_ID=your-project-id"
    exit 1
fi

echo "🪣 Creating GCS buckets for project: $GCP_PROJECT_ID"
echo ""

# Set the region (can be overridden with REGION env var)
REGION=${REGION:-us-central1}

# Create staging bucket
STAGING_BUCKET="gs://$GCP_PROJECT_ID-ipfs-staging"
echo "📦 Creating staging bucket: $STAGING_BUCKET"
if gsutil ls "$STAGING_BUCKET" &>/dev/null; then
    echo "✅ Staging bucket already exists"
else
    gsutil mb -l "$REGION" "$STAGING_BUCKET"
    echo "✅ Staging bucket created successfully"
fi

# Create production bucket
PROD_BUCKET="gs://$GCP_PROJECT_ID-ipfs-production"
echo "📦 Creating production bucket: $PROD_BUCKET"
if gsutil ls "$PROD_BUCKET" &>/dev/null; then
    echo "✅ Production bucket already exists"
else
    gsutil mb -l "$REGION" "$PROD_BUCKET"
    echo "✅ Production bucket created successfully"
fi

echo ""
echo "🎉 Bucket creation complete!"
echo ""
echo "📋 Buckets created:"
echo "   • Staging: $STAGING_BUCKET"
echo "   • Production: $PROD_BUCKET"
echo ""
echo "🔐 Don't forget to grant appropriate permissions to your service accounts!"