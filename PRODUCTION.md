# Production Deployment Guide

## Overview

This guide covers deploying IPFS-GCS to production using Kubernetes for geo-distributed, scalable deployment.

## Architecture

### Production Setup
- **Multiple Regions**: Deploy to multiple cloud regions
- **Shared GCS Bucket**: Single multi-region bucket for all instances
- **Load Balancing**: Global load balancer for geo-routing
- **Auto-scaling**: Horizontal Pod Autoscaler (HPA)
- **High Availability**: Multiple replicas with health checks

## Deployment Options

### Option 1: Google Kubernetes Engine (Recommended)

#### Single Region Deployment

```bash
# Create GKE cluster
gcloud container clusters create ipfs-gcs \
  --zone us-central1-a \
  --num-nodes 3 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10

# Get credentials
gcloud container clusters get-credentials ipfs-gcs --zone us-central1-a
```

#### Multi-Region Deployment

```bash
# Create multi-region GCS bucket
gsutil mb -c STANDARD -l US -b on gs://ipfs-global-production

# Deploy to multiple regions
for region in us-central1 europe-west1 asia-east1; do
  # Create regional cluster
  gcloud container clusters create ipfs-gcs-${region} \
    --region ${region} \
    --num-nodes 2 \
    --enable-autoscaling \
    --min-nodes 2 \
    --max-nodes 20
    
  # Deploy application
  kubectl config use-context gke_${PROJECT}_${region}_ipfs-gcs-${region}
  kubectl apply -f k8s/
done

# Set up Global Load Balancer
gcloud compute backend-services create ipfs-gcs-global \
  --global \
  --load-balancing-scheme=EXTERNAL \
  --protocol=HTTP
```

### Option 2: Generic Kubernetes

Works with any Kubernetes cluster (EKS, AKS, self-managed).

## Step-by-Step Deployment

### 1. Prepare Container Image

```bash
# Build production image
docker build -t gcr.io/YOUR_PROJECT/ipfs-gcs:v2.0.0 .

# Push to registry
docker push gcr.io/YOUR_PROJECT/ipfs-gcs:v2.0.0
```

### 2. Create Kubernetes Secret

```bash
# Create secret from service account key
kubectl create secret generic gcs-key \
  --from-file=key.json=serviceAccountKey.json
```

**For GKE**: Use Workload Identity instead (recommended):
```bash
# Create KSA
kubectl create serviceaccount ipfs-gcs-ksa

# Bind to GSA
gcloud iam service-accounts add-iam-policy-binding \
  ipfs-gcs-gsa@PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT.svc.id.goog[default/ipfs-gcs-ksa]"

# Annotate KSA
kubectl annotate serviceaccount ipfs-gcs-ksa \
  iam.gke.io/gcp-service-account=ipfs-gcs-gsa@PROJECT.iam.gserviceaccount.com
```

### 3. Configure Application

Edit `k8s/configmap.yaml`:
```yaml
data:
  bucket-name: "ipfs-global-production"  # Your production bucket
```

Edit `k8s/deployment.yaml`:
```yaml
spec:
  template:
    spec:
      containers:
      - name: ipfs-gcs
        image: gcr.io/YOUR_PROJECT/ipfs-gcs:v2.0.0  # Your image
```

### 4. Deploy to Kubernetes

```bash
# Apply all manifests
kubectl apply -f k8s/

# Verify deployment
kubectl get pods -l app=ipfs-gcs
kubectl get svc ipfs-gcs

# Check logs
kubectl logs -l app=ipfs-gcs -f
```

### 5. Configure HTTPS (Required for Production)

#### Using Google Cloud Load Balancer:
```bash
# Reserve static IP
gcloud compute addresses create ipfs-gcs-ip --global

# Create managed certificate
kubectl apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ipfs-gcs-cert
spec:
  domains:
    - ipfs.yourdomain.com
EOF
```

#### Using Cert-Manager:
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create Ingress with TLS
kubectl apply -f k8s/ingress-tls.yaml
```

## Monitoring and Operations

### Health Checks

The deployment includes:
- **Liveness Probe**: Restarts unhealthy pods
- **Readiness Probe**: Removes pods from load balancer when not ready

### Monitoring Setup

```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

# Configure alerts for:
# - High error rates
# - Slow response times
# - Pod restarts
# - GCS bucket quotas
```

### Logging

```bash
# View logs
kubectl logs -l app=ipfs-gcs -f

# For GKE, logs automatically go to Cloud Logging
gcloud logging read "resource.labels.cluster_name=ipfs-gcs"
```

## Performance Tuning

### Minimal Resource Configuration

This service is very lightweight - it only proxies data between GCS and HTTP. The default configuration uses minimal resources:

```yaml
resources:
  requests:
    memory: "64Mi"   # Minimal memory
    cpu: "50m"       # 0.05 CPU cores
  limits:
    memory: "128Mi"
    cpu: "100m"      # 0.1 CPU cores
```

These tiny pods can handle many concurrent requests since the actual data transfer happens directly between GCS and the client.

### Scale-to-Zero Configuration

For cost optimization, use KEDA to scale to zero when idle:

```bash
# Install KEDA
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml

# Apply KEDA ScaledObject (instead of HPA)
kubectl apply -f k8s/keda-scaledobject.yaml

# Delete the standard HPA if using KEDA
kubectl delete hpa ipfs-gcs-hpa
```

With KEDA:
- **0 pods** when no traffic (zero cost)
- **Automatic scale-up** on first request
- **5-minute cooldown** before scaling back to zero
- **Max 20 replicas** for burst traffic

### Node Pool Optimization

Use small, preemptible/spot nodes:

```bash
# GKE with e2-micro instances (0.25 vCPU, 1GB RAM)
gcloud container node-pools create micro-pool \
  --cluster=ipfs-gcs \
  --machine-type=e2-micro \
  --preemptible \
  --num-nodes=1 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=10

# Or use e2-small (0.5 vCPU, 2GB RAM) for more headroom
gcloud container node-pools create small-pool \
  --cluster=ipfs-gcs \
  --machine-type=e2-small \
  --spot \
  --num-nodes=1 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=20
```

### Cost Estimation

With scale-to-zero and spot instances:
- **Idle cost**: $0/month (scaled to zero)
- **Active cost**: ~$3-10/month per million requests
- **GCS storage**: $0.02/GB/month (multi-region)

### GCS Optimization

- Use multi-region bucket for global access
- Enable Cloud CDN for frequently accessed content
- Consider GCS lifecycle policies for old blocks

## Security Best Practices

1. **Use Workload Identity** (GKE) or IRSA (EKS)
2. **Enable Pod Security Standards**
3. **Network Policies** to restrict traffic
4. **Regular security scanning** of images
5. **Encrypt service-to-service communication**
6. **API rate limiting** with Istio or similar

## Disaster Recovery

### Backup Strategy

```bash
# Backup GCS bucket to another region
gsutil -m rsync -r gs://ipfs-production gs://ipfs-backup

# Schedule regular backups
# Create Cloud Scheduler job for automated backups
```

### Multi-Region Failover

1. Deploy to multiple regions
2. Use Global Load Balancer with health checks
3. Automatic failover on region failure

## Cost Optimization

1. **Use Spot/Preemptible nodes** for non-critical workloads
2. **Enable cluster autoscaling** to scale down during low traffic
3. **GCS lifecycle rules** to move old blocks to cheaper storage
4. **Monitor and optimize** resource requests/limits

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Check service account permissions
   - Verify Workload Identity binding

2. **High Memory Usage**
   - Blocks are cached in memory
   - Increase memory limits or implement LRU cache

3. **Slow Downloads**
   - Check region proximity
   - Enable Cloud CDN
   - Increase replica count

### Debug Commands

```bash
# Enter pod shell
kubectl exec -it $(kubectl get pod -l app=ipfs-gcs -o jsonpath='{.items[0].metadata.name}') -- sh

# Check GCS connectivity
kubectl exec deployment/ipfs-gcs -- gsutil ls gs://YOUR_BUCKET/

# Test from inside cluster
kubectl run test --rm -it --image=curlimages/curl -- sh
curl http://ipfs-gcs-internal:3000/health
```