#!/bin/bash

# Complete Deployment Script for Design Den Vue v2
set -e

# Configuration
IMAGE_NAME="ghcr.io/leaptechnology/design-den-vue-v2"
COMPOSE_FILE="docker-compose.prod.yaml"
VITE_API_BASE_URL="https://stage2-api.designden.sg"
VITE_ADOBE_PDF_CLIENT_ID="c4dc78031957432b8019143c37bd5dce"


# Generate tag
TAG="stage-$(date +'%d-%m-%Y-%H%M')"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Display deployment info
log_info "Starting Vue.js application deployment"
log_info "Generated TAG: $TAG"

# Check for required tokens
if [ -z "$CR_PAT" ]; then
    read -sp "Enter your GitHub Access Token: " CR_PAT
    echo
fi

if [ -z "$CR_PAT" ]; then
    log_error "No GitHub token provided. Exiting."
    exit 1
fi

# Login to GitHub Container Registry
log_info "Logging in to GitHub Container Registry..."
if ! echo "$CR_PAT" | docker login ghcr.io -u leaptechnology --password-stdin; then
    log_error "Login failed. Please check your token and permissions"
    exit 1
fi
log_info "Login succeeded"

# Build Docker Image
log_info "Building Docker image with buildx..."
if ! docker buildx build --platform linux/amd64 \
    --build-arg VITE_API_BASE_URL="$VITE_API_BASE_URL" \
    --build-arg VITE_ADOBE_PDF_CLIENT_ID="$VITE_ADOBE_PDF_CLIENT_ID" \
    -t $IMAGE_NAME:$TAG \
    -f ./prod.Dockerfile .; then
    log_error "Docker build failed"
    exit 1
fi
log_info "Docker build completed successfully"

# Push Docker Image
log_info "Pushing Docker image to registry..."
if ! docker push $IMAGE_NAME:$TAG; then
    log_error "Docker push failed"
    exit 1
fi
log_info "Docker push completed successfully"

# Optional: Deploy to remote server
if [ -n "$SERVER_IP" ] && [ -n "$REMOTE_PATH" ]; then
    log_info "Starting remote deployment..."
    
    # Copy docker-compose file to server
    log_info "Copying compose file to remote server..."
    scp -o StrictHostKeyChecking=no $COMPOSE_FILE root@$SERVER_IP:$REMOTE_PATH/
    
    # Deploy on remote server
    log_info "Deploying on remote server..."
    ssh root@$SERVER_IP "
        set -e
        cd $REMOTE_PATH
        
        # Login to GHCR on remote
        echo '$CR_PAT' | docker login ghcr.io -u leaptechnology --password-stdin
        
        # Pull latest image
        docker pull $IMAGE_NAME:$TAG
        
        # Stop and start containers
        TAG=$TAG docker compose -f $COMPOSE_FILE down
        TAG=$TAG docker compose -f $COMPOSE_FILE up -d
        
        # Cleanup old images
        docker images $IMAGE_NAME \
            --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}}' \
            | grep -v ':$TAG' \
            | grep -v ':<none>' \
            | sort -r \
            | tail -n +4 \
            | awk '{print \$1}' \
            | xargs -r docker rmi || true
            
        echo 'Deployment completed on server'
    "
    
    log_info "Remote deployment completed successfully"
fi

log_info "🎉 Deployment completed successfully!"
echo "=== DEPLOYMENT SUMMARY ==="
echo "TAG: $TAG"
echo "IMAGE: $IMAGE_NAME:$TAG"
echo "Build args:"
echo "  - VITE_API_BASE_URL: $VITE_API_BASE_URL"
echo "  - VITE_ADOBE_PDF_CLIENT_ID: $VITE_ADOBE_PDF_CLIENT_ID"
if [ -n "$SERVER_IP" ]; then
    echo "Deployed to server: $SERVER_IP"
fi