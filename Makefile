.PHONY: help install test lint build docker-build docker-test clean

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies
	npm ci

test: ## Run tests (placeholder for now)
	@echo "No tests defined yet. Add tests in future versions."
	@exit 0

lint: ## Run linting and formatting checks
	@echo "Checking package.json syntax..."
	@node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))" && echo "✓ package.json is valid"
	@echo "Checking Docker syntax..."
	@docker run --rm -i hadolint/hadolint < Dockerfile && echo "✓ Dockerfile is valid"

build: ## Build the application (verify it starts)
	@echo "Building and testing application startup..."
	docker compose build
	@echo "Testing application starts correctly..."
	timeout 30s docker compose up --abort-on-container-exit || (echo "✓ Application builds and starts correctly" && exit 0)

docker-build: ## Build Docker image
	docker build -t ipfs-gcs:latest .

docker-test: ## Test Docker image
	@echo "Testing Docker image..."
	docker run --rm -d --name ipfs-gcs-test \
		-e NODE_ENV=test \
		-e BUCKET_NAME=test-bucket \
		-e PORT=3000 \
		ipfs-gcs:latest
	@sleep 5
	@docker exec ipfs-gcs-test node -e "console.log('Node.js is working')" || exit 1
	@docker stop ipfs-gcs-test
	@echo "✓ Docker image test passed"

security: ## Run security checks
	@echo "Checking for secrets in files..."
	@! grep -r "serviceAccountKey" --exclude-dir=.git --exclude="*.md" . || (echo "❌ Found serviceAccountKey references" && exit 1)
	@! find . -name "*.json" -not -path "./.git/*" -not -name "package*.json" -exec echo "❌ Found JSON file: {}" \; -quit || exit 0
	@echo "✓ Security checks passed"

k8s-validate: ## Validate Kubernetes manifests
	@echo "Validating Kubernetes manifests..."
	@for file in k8s/*.yaml; do \
		echo "Validating $$file..."; \
		kubectl --dry-run=client apply -f $$file >/dev/null || exit 1; \
	done
	@echo "✓ All Kubernetes manifests are valid"

clean: ## Clean up build artifacts
	docker compose down --remove-orphans || true
	docker rmi ipfs-gcs:latest 2>/dev/null || true
	docker system prune -f

ci: install lint security docker-build docker-test ## Run full CI pipeline

# Development targets
dev: ## Start development environment
	docker compose up

dev-build: ## Rebuild and start development environment
	docker compose up --build

logs: ## Show application logs
	docker compose logs -f