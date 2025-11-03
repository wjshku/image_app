#!/bin/bash

echo "Building Docker images for Image Understanding Application..."

# Stop and remove existing containers if they exist
echo "Checking for existing containers..."
CONTAINERS=("image-model" "image-backend" "image-frontend" "nginx")
for container in "${CONTAINERS[@]}"; do
    if sudo docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "Stopping existing container: ${container}"
        sudo docker stop ${container} 2>/dev/null || true
        echo "Removing existing container: ${container}"
        sudo docker rm ${container} 2>/dev/null || true
    fi
done

# Create bridge network (ignore if already exists)
echo "Creating Docker network..."
sudo docker network create image-network 2>/dev/null || echo "Network image-network already exists"

# Load base images (if they exist)
# sudo docker load -i docker_base/node.tar.gz 2>/dev/null || echo "Base images not found, will use Docker Hub"

# Build backend service
echo "Building backend service..."
if ! sudo docker build -t image-backend:1.0 ./backend; then
    echo "ERROR: Failed to build image-backend:1.0"
    exit 1
fi

# Build frontend service
echo "Building frontend service..."
if ! sudo docker build -t image-frontend:1.0 ./frontend; then
    echo "ERROR: Failed to build image-frontend:1.0"
    exit 1
fi

# Build model service
echo "Building model service..."
if ! sudo docker build -t image-model:1.0 ./model; then
    echo "ERROR: Failed to build image-model:1.0"
    exit 1
fi

# Build nginx service
echo "Building nginx service..."
if ! sudo docker build -t image-nginx:1.0 ./nginx; then
    echo "ERROR: Failed to build image-nginx:1.0"
    exit 1
fi

# Verify all images were built successfully
echo "Verifying built images..."
missing_images=0
for image in image-backend:1.0 image-frontend:1.0 image-model:1.0 image-nginx:1.0; do
    if ! sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        echo "ERROR: Image ${image} not found after build"
        missing_images=1
    else
        echo "✓ Image ${image} built successfully"
    fi
done

if [ $missing_images -eq 1 ]; then
    echo "ERROR: Some images failed to build"
    exit 1
fi

echo ""
echo "All Docker images built successfully!"
