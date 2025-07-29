# ipfs-gcs-example

[![CI](https://github.com/postfiatorg/ipfs-gcs/actions/workflows/ci.yml/badge.svg)](https://github.com/postfiatorg/ipfs-gcs/actions/workflows/ci.yml)
[![Docker](https://github.com/postfiatorg/ipfs-gcs/actions/workflows/docker.yml/badge.svg)](https://github.com/postfiatorg/ipfs-gcs/actions/workflows/docker.yml)
[![Deploy](https://github.com/postfiatorg/ipfs-gcs/actions/workflows/deploy.yml/badge.svg)](https://github.com/postfiatorg/ipfs-gcs/actions/workflows/deploy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

IPFS implementation with Google Cloud Storage backend using Helia, Express.js, and Docker.

## Features

- IPFS file storage using Helia (modern IPFS implementation)
- Google Cloud Storage as persistent block storage
- REST API for file upload/download
- Docker Compose setup for easy deployment
- Memory cache with GCS fallback for optimal performance
- Kubernetes-ready for production deployment

## Quick Start

### Local Development

```bash
# Clone the repository
git clone https://github.com/allenday/ipfs-gcs-example.git
cd ipfs-gcs-example

# Copy environment variables
cp .env.example .env

# Add your GCS service account key
# Edit .env with your bucket name

# Run with Docker Compose
docker compose up
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed development setup.

### Production Deployment

```bash
# Quick deploy to Kubernetes
kubectl create secret generic gcs-key --from-file=key.json=serviceAccountKey.json
kubectl apply -f k8s/
```

See [PRODUCTION.md](PRODUCTION.md) for detailed production deployment guide.

## API Usage

### Upload File
```bash
curl -F "upload=@/path/to/file" -X POST http://localhost:3000/upload
```

### Download File
```bash
curl http://localhost:3000/download/ipfs/[hash]
```

### Health Check
```bash
curl http://localhost:3000/health
```

## Architecture

The application uses:
- **Helia**: Modern IPFS implementation for content addressing
- **Custom GCS Blockstore**: Stores IPFS blocks in Google Cloud Storage
- **Express.js**: Lightweight REST API server
- **Docker**: Containerized deployment

All uploaded files are content-addressed using IPFS and stored as blocks in your GCS bucket under the `blocks/` prefix.

## Development

### Quick Commands

```bash
# Show all available commands
make help

# Start development environment
make dev

# Run full CI pipeline locally
make ci

# Build and test Docker image
make docker-build docker-test

# Get deployed environment URLs
make get-staging-url
make get-prod-url

# Run smoke tests against deployed environments
make smoke-test-staging
make smoke-test-prod

# Set up branch protection (one-time setup)
make setup-branch-protection
```

### Documentation

- [Development Guide](docs/DEVELOPMENT.md) - Local setup, debugging, architecture details
- [Production Guide](docs/PRODUCTION.md) - Kubernetes deployment, scaling, monitoring
- [Deployment Guide](docs/DEPLOYMENT.md) - CI/CD setup and deployment workflows
- [Branch Protection Setup](.github/BRANCH_PROTECTION.md) - Repository security and workflow
- [Kubernetes Manifests](k8s/README.md) - K8s configuration details

## License

MIT

---

*Based on original work from [catcatio/ipfs-gcs](https://github.com/catcatio/ipfs-gcs)*