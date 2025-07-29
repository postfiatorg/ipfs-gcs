# Quick CD Test Setup

## 1. Create New GCP Project

```bash
# Create a new project for testing
export PROJECT_ID="ipfs-gcs-test-$(date +%s)"
gcloud projects create $PROJECT_ID
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable storage.googleapis.com

# Set up billing (required for GKE)
# Go to console.cloud.google.com and enable billing for the project
```

## 2. Create Minimal Test Clusters

```bash
# Create tiny staging cluster (cheapest possible)
gcloud container clusters create ipfs-gcs-staging \
  --zone us-central1-a \
  --num-nodes 1 \
  --machine-type e2-micro \
  --disk-size 10GB \
  --spot \
  --enable-autoscaling \
  --min-nodes 0 \
  --max-nodes 2 \
  --project $PROJECT_ID

# Create production cluster (slightly bigger)
gcloud container clusters create ipfs-gcs-prod \
  --zone us-central1-a \
  --num-nodes 1 \
  --machine-type e2-small \
  --disk-size 10GB \
  --spot \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 3 \
  --project $PROJECT_ID
```

## 3. Create Service Account

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --description="GitHub Actions CD" \
  --display-name="GitHub Actions"

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Create and download key
gcloud iam service-accounts keys create ~/github-actions-key.json \
  --iam-account=github-actions@$PROJECT_ID.iam.gserviceaccount.com

echo "Service account key saved to ~/github-actions-key.json"
echo "Project ID: $PROJECT_ID"
```

## 4. GitHub Configuration

1. **Add Repository Secrets**:
   - `GCP_PROJECT_ID`: Copy the project ID from above
   - `GCP_SA_KEY`: Copy contents of `~/github-actions-key.json`
   - `GKE_ZONE`: `us-central1-a`

2. **Create Environments**:
   - Go to Settings → Environments
   - Create `staging` (no restrictions)
   - Create `production` (add yourself as required reviewer)

## 5. Test the CD Pipeline

### Option A: Automatic Staging Deploy
```bash
# Make a small change and push to main
echo "# Test change" >> README.md
git add -A
git commit -m "Test CD pipeline"
git push origin main

# Watch the deployment: GitHub → Actions tab
```

### Option B: Manual Deploy
1. Go to GitHub Actions tab
2. Click "Deploy" workflow
3. Click "Run workflow"
4. Select "staging" environment
5. Click "Run workflow"

### Option C: Production Deploy (with tag)
```bash
# Create a release tag
git tag v1.0.0
git push origin v1.0.0

# This will trigger production deployment (requires approval)
```

## 6. Verify Deployment

```bash
# Get credentials for staging cluster
gcloud container clusters get-credentials ipfs-gcs-staging --zone us-central1-a

# Check if pods are running
kubectl get pods -n staging

# Get service external IP (may take a few minutes)
kubectl get svc ipfs-gcs -n staging

# Test the service
EXTERNAL_IP=$(kubectl get svc ipfs-gcs -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP/health
```

## 7. Cleanup (when done testing)

```bash
# Delete clusters
gcloud container clusters delete ipfs-gcs-staging --zone us-central1-a --quiet
gcloud container clusters delete ipfs-gcs-prod --zone us-central1-a --quiet

# Delete the test project (removes everything)
gcloud projects delete $PROJECT_ID
```

## Expected Costs

- **e2-micro spot instances**: ~$3-5/month per cluster
- **Load balancer**: ~$18/month (you can use NodePort to avoid this)
- **Storage**: ~$1/month

**Total test cost**: ~$10-15/month (delete when done testing)

## Troubleshooting

### Common Issues

1. **"Billing not enabled"**
   - Go to console.cloud.google.com
   - Select your project → Billing → Link billing account

2. **"Insufficient quota"** 
   - Use different zones: `us-west1-a`, `europe-west1-b`
   - Request quota increase in console

3. **"Service account not found"**
   - Check the service account email matches exactly
   - Verify the JSON key is complete

4. **"Cluster not found"**
   - Verify cluster names match exactly in the deployment YAML
   - Check zones match between cluster creation and deployment

### View Logs

```bash
# GitHub Actions logs: Go to Actions tab in GitHub
# Kubernetes logs:
kubectl logs -l app=ipfs-gcs -n staging -f
kubectl describe deployment ipfs-gcs -n staging
```