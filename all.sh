#!/bin/bash

echo "=========================================="
echo "Image Understanding Application Setup"
echo "=========================================="
echo ""

# Stop and remove existing containers if they exist
echo "Step 1: Cleaning up existing containers..."
CONTAINERS=("image-model" "image-backend" "image-frontend" "test-frontend" "nginx")
containers_found=0
for container in "${CONTAINERS[@]}"; do
    if sudo docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "  Found container: ${container}"
        containers_found=1
        if sudo docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            echo "  Stopping container: ${container}"
            sudo docker stop ${container} 2>/dev/null || true
        fi
        echo "  Removing container: ${container}"
        sudo docker rm ${container} 2>/dev/null || true
    fi
done

if [ $containers_found -eq 0 ]; then
    echo "  No existing containers found"
fi
echo ""

# Run first.sh for initial setup
echo "Step 2: Running initial setup (first.sh)..."
bash first.sh
echo ""

# Build Docker images (this will also clean up containers)
echo "Step 3: Building Docker images..."
bash docker_build.sh
if [ $? -ne 0 ]; then
    echo "ERROR: Docker build failed"
    exit 1
fi
echo ""

# Run containers
echo "Step 4: Starting containers..."
bash docker_run.sh
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start containers"
    exit 1
fi
echo ""

# Wait a bit for services to stabilize
echo "Step 5: Waiting for services to stabilize..."
sleep 5

# Final check
echo "Step 6: Verifying all containers are running..."
lines=$(sudo docker ps -f name=image-backend -f name=image-frontend -f name=test-frontend -f name=image-model -f name=nginx | wc -l | awk '{print $1 - 1}')
if [ $lines -eq 5 ]; then
    echo ""
    echo "=========================================="
    echo "✓ All containers are running successfully!"
    echo "=========================================="
    echo ""
    echo "Applications are available at:"
    echo "  - Image App: http://app.trisure.me (or http://localhost)"
    echo "  - Test Page: http://test.trisure.me"
    echo ""
    echo "To view logs:"
    echo "  sudo docker logs -f image-backend"
    echo "  sudo docker logs -f image-model"
    echo "  sudo docker logs -f image-frontend"
    echo "  sudo docker logs -f test-frontend"
    echo "  sudo docker logs -f nginx"
else
    echo ""
    echo "=========================================="
    echo "✗ ERROR: Not all containers are running"
    echo "=========================================="
    echo ""
    echo "Running containers:"
    sudo docker ps -f name=image-backend -f name=image-frontend -f name=test-frontend -f name=image-model -f name=nginx
    echo ""
    echo "All containers (including stopped):"
    sudo docker ps -a -f name=image-backend -f name=image-frontend -f name=test-frontend -f name=image-model -f name=nginx
    echo ""
    echo "Please check the logs above for errors"
    exit 1
fi
