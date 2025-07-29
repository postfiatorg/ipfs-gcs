# Development Guide

## Prerequisites

- Docker and Docker Compose
- Node.js 22+ (if running locally without Docker)
- Google Cloud Platform account
- Service account key with Storage Object Admin permissions

## Local Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/allenday/ipfs-gcs-example.git
cd ipfs-gcs-example
```

### 2. Environment Configuration

Copy `.env.example` to `.env` and update with your values:

```bash
cp .env.example .env
```

Edit `.env`:
```env
NODE_ENV=development
GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json
BUCKET_NAME=ipfs-example-dev  # Use a dev bucket
PORT=3000
```

### 3. Google Cloud Setup

1. Create a service account in your GCP project
2. Download the service account key JSON
3. Save it as `serviceAccountKey.json` in the project root
4. Create a GCS bucket or update `BUCKET_NAME` in `.env`

### 4. Run with Docker Compose

```bash
docker compose up
```

This starts the application with:
- Hot-reloading via nodemon
- Port 3000 exposed
- Volume mounts for live code updates

### 5. Run Locally (without Docker)

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev
```

## Development Workflow

### Making Changes

1. Code changes in `/src` are automatically reloaded
2. Environment changes require container restart
3. Package changes require rebuild: `docker compose build`

### Testing

```bash
# Health check
curl http://localhost:3000/health

# Upload a file
curl -F "upload=@test.txt" -X POST http://localhost:3000/upload

# Download a file
curl http://localhost:3000/download/ipfs/[hash]
```

### Debugging

- View logs: `docker compose logs -f`
- Enter container: `docker compose exec ipfsjs-gcs sh`
- Check GCS bucket: `gsutil ls -r gs://your-bucket/`

## Project Structure

```
├── src/
│   ├── index.js          # Entry point
│   ├── server.js         # Server setup
│   ├── config.js         # Configuration
│   ├── initExpress.js    # Express initialization
│   ├── initGcs.js        # GCS client setup
│   ├── initIpfs.js       # IPFS/Helia with GCS blockstore
│   └── routers/
│       └── index.js      # API routes
├── .env.example          # Environment template
├── docker-compose.yml    # Local development setup
├── Dockerfile           # Container definition
└── package.json         # Dependencies
```

## Architecture Notes

### GCS Blockstore

The custom `GCSBlockstore` class:
- Extends `MemoryBlockstore` for caching
- Persists blocks to GCS on write
- Falls back to GCS on cache miss
- Uses base32 encoding for CID filenames

### API Design

- `POST /upload` - Accepts multipart file uploads
- `GET /download/ipfs/:cid` - Streams file content
- `GET /health` - Health check endpoint

## Common Issues

### Permission Errors
Ensure your service account has Storage Object Admin role:
```bash
gsutil iam ch serviceAccount:YOUR_SA@PROJECT.iam.gserviceaccount.com:objectAdmin gs://YOUR_BUCKET
```

### Port Conflicts
Change the PORT in `.env` if 3000 is already in use.

### Node Version
Requires Node.js 22+ for Promise.withResolvers support.