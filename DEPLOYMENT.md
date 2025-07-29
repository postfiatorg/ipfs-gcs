# Deployment Guide

This document explains how to set up Continuous Deployment (CD) from GitHub to Google Kubernetes Engine (GKE).

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **GKE clusters** created for staging and production
3. **Service Account** with deployment permissions
4. **GitHub repository** with appropriate secrets configured

## Initial GCP Setup

### 1. Create GKE Clusters

```bash
# Set your project ID
export GCP_PROJECT_ID="your-project-id"

# Create staging cluster
gcloud container clusters create ipfs-gcs-staging \
  --zone us-central1-a \
  --num-nodes 2 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 5 \
  --machine-type e2-small \
  --spot \
  --project $GCP_PROJECT_ID

# Create production cluster  
gcloud container clusters create ipfs-gcs-prod \
  --zone us-central1-a \
  --num-nodes 3 \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 10 \
  --machine-type e2-standard-2 \
  --project $GCP_PROJECT_ID
```

### 2. Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --description="Service account for GitHub Actions CD" \
  --display-name="GitHub Actions" \
  --project $GCP_PROJECT_ID

# Grant necessary permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com \
  --project $GCP_PROJECT_ID
```

### 3. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions, and add:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `GCP_PROJECT_ID` | your-project-id | Your Google Cloud Project ID |
| `GCP_SA_KEY` | (contents of github-actions-key.json) | Service account key JSON |
| `GKE_ZONE` | us-central1-a | Zone where your clusters are located |

### 4. Set up GitHub Environments

1. Go to Settings → Environments
2. Create two environments: `staging` and `production`
3. For production environment, add protection rules:
   - Required reviewers
   - Wait timer (optional)
   - Deployment branches (only tags/main)

## Deployment Workflows

### Automatic Deployments

- **Staging**: Deploys automatically on every push to `main` branch
- **Production**: Deploys automatically on tagged releases (`v*`)

### Manual Deployments

You can trigger manual deployments:

1. Go to Actions tab in GitHub
2. Select "Deploy" workflow
3. Click "Run workflow"
4. Choose environment (staging/production)

### Local Deployments

You can also deploy locally using Make:

```bash
# Set your project ID
export GCP_PROJECT_ID="your-project-id"

# Deploy to staging
make deploy-staging

# Deploy to production (with confirmation prompt)
make deploy-prod
```

## Deployment Process

The CD pipeline does the following:

1. **Build**: Creates Docker image with commit SHA tag
2. **Push**: Pushes image to Google Container Registry
3. **Deploy**: Updates Kubernetes deployment with new image
4. **Verify**: Checks rollout status and runs health check

## Monitoring Deployments

### Check Deployment Status

```bash
# Get cluster credentials
gcloud container clusters get-credentials ipfs-gcs-staging --zone us-central1-a

# Check deployment status
kubectl get deployments -n staging
kubectl get pods -n staging
kubectl get services -n staging

# Check logs
kubectl logs -l app=ipfs-gcs -n staging -f
```

### Health Checks

The deployment includes health checks:
- **Liveness probe**: Restarts unhealthy containers
- **Readiness probe**: Only routes traffic to ready containers
- **External health check**: Tests `/health` endpoint after deployment

## Rollback

If a deployment fails, you can rollback:

```bash
# Rollback to previous version
kubectl rollout undo deployment/ipfs-gcs -n staging

# Rollback to specific revision
kubectl rollout undo deployment/ipfs-gcs --to-revision=2 -n staging

# Check rollout history
kubectl rollout history deployment/ipfs-gcs -n staging
```

## Environment Configuration

### Staging Environment
- **Cluster**: `ipfs-gcs-staging`
- **Namespace**: `staging`
- **Resources**: Minimal (e2-small nodes)
- **Auto-scaling**: 1-5 nodes

### Production Environment
- **Cluster**: `ipfs-gcs-prod`
- **Namespace**: `default`
- **Resources**: Higher (e2-standard-2 nodes)
- **Auto-scaling**: 2-10 nodes

## Security Considerations

1. **Service Account**: Has minimal required permissions
2. **Secrets**: Stored securely in GitHub Secrets
3. **Environments**: Production requires approval
4. **Image Scanning**: Automatic vulnerability scanning
5. **Network Policies**: Restrict pod-to-pod communication

## Cost Optimization

- **Staging**: Uses spot instances for 60-90% cost reduction
- **Auto-scaling**: Scales down during low usage
- **Resource limits**: Prevents resource waste
- **KEDA**: Can scale to zero for ultimate cost savings

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Check service account permissions
   - Verify GCP_SA_KEY secret is correct

2. **Cluster Not Found**
   - Verify cluster names and zones
   - Check GCP_PROJECT_ID is correct

3. **Image Pull Errors**
   - Ensure Docker image was built and pushed
   - Check Container Registry permissions

4. **Deployment Timeout**
   - Check pod logs for application errors
   - Verify resource requests/limits

### Debug Commands

```bash
# Check GitHub Actions logs in the Actions tab

# Local debugging
kubectl describe deployment ipfs-gcs -n staging
kubectl logs -l app=ipfs-gcs -n staging --tail=50
kubectl get events -n staging --sort-by='.lastTimestamp'
```

## Advanced Features

### Blue-Green Deployments

For zero-downtime deployments, consider implementing blue-green deployments using:
- Argo Rollouts
- Flagger
- Istio traffic splitting

### GitOps

For more advanced CD, consider GitOps tools:
- ArgoCD
- Flux
- Jenkins X

These tools provide:
- Git-based configuration
- Automatic drift detection
- Rollback capabilities
- Multi-environment management