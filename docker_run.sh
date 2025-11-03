#!/bin/bash

echo "Starting Image Understanding Application containers..."

# Check if required images exist
echo "Checking required Docker images..."
missing_images=0
for image in image-backend:1.0 image-frontend:1.0 image-model:1.0 image-nginx:1.0; do
    if ! sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        echo "ERROR: Image ${image} not found. Please run ./docker_build.sh first."
        missing_images=1
    fi
done

if [ $missing_images -eq 1 ]; then
    echo "ERROR: Missing required images. Exiting."
    exit 1
fi

# Stop and remove existing containers if they exist
echo "Cleaning up existing containers..."
for container in image-model image-backend image-frontend nginx; do
    if sudo docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "Stopping and removing existing container: ${container}"
        sudo docker stop ${container} 2>/dev/null || true
        sudo docker rm ${container} 2>/dev/null || true
    fi
done

# Start model service (with GPU if available)
if nvidia-smi &> /dev/null; then
    echo "Starting model service with GPU support..."
    sudo docker run -d \
        -v /etc/timezone:/etc/timezone:ro \
        -v /etc/localtime:/etc/localtime:ro \
        --name image-model \
        --network image-network \
        -p 23333:23333 \
        --gpus all \
        --restart always \
        image-model:1.0
else
    echo "Starting model service without GPU support..."
    sudo docker run -d \
        -v /etc/timezone:/etc/timezone:ro \
        -v /etc/localtime:/etc/localtime:ro \
        --name image-model \
        --network image-network \
        -p 23333:23333 \
        --restart always \
        image-model:1.0
fi

# Wait for model service to be ready
echo "Waiting for model service to start..."
sleep 10

# Check if model container is running
if ! sudo docker ps --format "{{.Names}}" | grep -q "^image-model$"; then
    echo "ERROR: Model service container failed to start!"
    echo "Check logs: sudo docker logs image-model"
    exit 1
fi

echo "Model service container is running (may still be initializing)..."
echo "Note: Model service may take 1-5 minutes to fully initialize depending on hardware"

# Start backend service
echo "Starting backend service..."
sudo docker run -d \
    -v /etc/timezone:/etc/timezone:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --name image-backend \
    --network image-network \
    --restart always \
    image-backend:1.0

# Wait for backend to be ready
sleep 3

# Start frontend service
echo "Starting frontend service..."
sudo docker run -d \
    -v /etc/timezone:/etc/timezone:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --name image-frontend \
    --network image-network \
    --restart always \
    image-frontend:1.0

# Wait for frontend to be ready
sleep 2

# Start nginx reverse proxy
echo "Starting nginx reverse proxy..."
sudo docker run -d \
    -v /etc/timezone:/etc/timezone:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --name nginx \
    --network image-network \
    -p 80:80 \
    --restart always \
    image-nginx:1.0

# Wait for nginx to be ready
sleep 2

# Verify all containers are running
echo "Verifying container status..."
failed_containers=0
for container in image-model image-backend image-frontend nginx; do
    if ! sudo docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "ERROR: Container ${container} failed to start"
        echo "Checking logs:"
        sudo docker logs ${container} 2>&1 | tail -20
        failed_containers=1
    else
        echo "✓ Container ${container} is running"
    fi
done

if [ $failed_containers -eq 1 ]; then
    echo "ERROR: Some containers failed to start. Check logs above."
    exit 1
fi

echo ""
echo "All containers started successfully!"
echo "Application will be available at: http://localhost"
echo "Model API documentation: http://localhost:23333"
echo ""
echo "To view logs, use:"
echo "  sudo docker logs -f image-backend"
echo "  sudo docker logs -f image-model"
