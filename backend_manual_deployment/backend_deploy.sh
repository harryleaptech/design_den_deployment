#!/bin/bash

# Deployment Script for Design Den Laravel v2 (Interactive Version)
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Set image name
IMAGE_NAME="ghcr.io/leaptechnology/design-den-laravel-v2"
TAG="stage-$(date +'%d-%m-%Y-%H%M')"

log_info "Generated TAG: $TAG"

# Get CR_PAT from user if not set
if [ -z "$CR_PAT" ]; then
    log_warn "CR_PAT environment variable is not set"
    read -sp "Enter your GitHub Personal Access Token: " CR_PAT
    echo
fi

if [ -z "$CR_PAT" ]; then
    log_error "No token provided. Exiting."
    exit 1
fi

# Login to GitHub Container Registry
log_info "Logging in to GitHub Container Registry..."
if echo "$CR_PAT" | docker login ghcr.io -u leaptechnology --password-stdin; then
    log_info "Login succeeded"
else
    log_error "Login failed. Please check your token and permissions"
    exit 1
fi

# Build Docker Image
log_info "Building Docker image..."
if docker build \
    --pull \
    --target production \
    -t $IMAGE_NAME:$TAG \
    -f ./docker/common/php-fpm/Dockerfile .; then
    log_info "Docker build completed successfully"
else
    log_error "Docker build failed"
    exit 1
fi

# Push Docker Image
log_info "Pushing Docker image..."
if docker push $IMAGE_NAME:$TAG; then
    log_info "Docker push completed successfully"
    log_info "Image available at: $IMAGE_NAME:$TAG"
else
    log_error "Docker push failed"
    exit 1
fi

log_info "Deployment script completed!"
echo "=== SUMMARY ==="
echo "TAG: $TAG"
echo "IMAGE: $IMAGE_NAME:$TAG"