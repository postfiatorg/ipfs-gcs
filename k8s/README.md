# Kubernetes Deployment

This directory contains Kubernetes manifests for production deployment.

## Prerequisites

- Kubernetes cluster (GKE, EKS, AKS, etc.)
- kubectl configured
- Docker registry for your images
- Google Cloud service account with Storage Object Admin permissions

## Deployment Steps

### 1. Create GCS Service Account Secret

```bash
kubectl create secret generic gcs-key \
  --from-file=key.json=../serviceAccountKey.json
```

### 2. Update Configuration

Edit `configmap.yaml` to set your production bucket name.

### 3. Build and Push Docker Image

```bash
# Build the image
docker build -t your-registry/ipfs-gcs-example:latest .

# Push to registry
docker push your-registry/ipfs-gcs-example:latest
```

### 4. Update Image in Deployment

Edit `deployment.yaml` and update the image reference to your registry.

### 5. Deploy to Kubernetes

```bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -l app=ipfs-gcs
kubectl get svc ipfs-gcs
```

## Multi-Region Deployment

For geo-distributed deployment:

1. **Use Google Kubernetes Engine (GKE)** with multi-region clusters
2. **Or deploy to multiple regions** and use:
   - Global Load Balancer (GCP)
   - Traffic Director for service mesh
   - Single global GCS bucket (multi-region)

### Example: GKE Multi-Region

```bash
# Create a multi-region GKE cluster
gcloud container clusters create ipfs-gcs-global \
  --region us-central1 \
  --node-locations us-central1-a,us-central1-b,us-central1-c \
  --num-nodes 2 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10

# Deploy to multiple regions
for region in us-central1 europe-west1 asia-east1; do
  kubectl config use-context gke_${PROJECT}_${region}_ipfs-gcs
  kubectl apply -f k8s/
done
```

## Monitoring

Consider adding:
- Prometheus metrics
- Grafana dashboards
- Google Cloud Monitoring
- Distributed tracing with OpenTelemetry

## Cost Optimization

### Scale-to-Zero

For minimal costs, use KEDA to scale to zero when idle:

```bash
# Install KEDA
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml

# Use KEDA ScaledObject instead of HPA
kubectl apply -f keda-scaledobject.yaml
kubectl delete hpa ipfs-gcs-hpa  # Remove standard HPA
```

### Resource Configuration

The default configuration uses minimal resources:
- **CPU**: 50m request (0.05 cores)
- **Memory**: 64Mi request
- **Pods**: Can run 20+ pods per small node

This works because the service is mostly I/O bound - it just streams data between GCS and HTTP clients.

## Security Considerations

1. Use Workload Identity (GKE) instead of service account keys
2. Enable Pod Security Standards
3. Use NetworkPolicies to restrict traffic
4. Regular security scanning of images