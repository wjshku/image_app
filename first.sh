#!/bin/bash

echo "Setting up server environment for Image Understanding Application..."

# Install NVIDIA driver (uncomment if needed)
# sudo apt install nvidia-driver-570
# sudo apt-mark hold nvidia-driver-570

# Install Docker environment
echo "Installing Docker..."
# Allow APT to use HTTPS
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker stable repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
sudo apt-get update

# Install Docker CE
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install NVIDIA container runtime (if GPU available)
if nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected, checking NVIDIA container toolkit..."

    # Check if NVIDIA container toolkit is already installed
    if ! dpkg -l | grep -q nvidia-container-toolkit; then
        echo "Installing NVIDIA container toolkit..."

        # Add NVIDIA container toolkit repository
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
          sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
          sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

        sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit

        # Configure Docker to use NVIDIA runtime
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl daemon-reload
        sudo systemctl restart docker

        echo "NVIDIA container toolkit installed and configured"
    else
        echo "NVIDIA container toolkit already installed, skipping installation"
    fi

    # Pre-download NVIDIA images for the application
    echo "Pre-downloading NVIDIA images for Image Understanding Application..."

    # Pull the CUDA image used by the model service
    if ! sudo docker images | grep -q "nvidia/cuda.*11.8.0-cudnn8-runtime"; then
        echo "Downloading NVIDIA CUDA 11.8 image..."
        sudo docker pull nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04
    else
        echo "NVIDIA CUDA image already downloaded"
    fi

    # Test GPU functionality
    echo "Testing GPU functionality..."
    if sudo docker run --rm --gpus all nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 nvidia-smi > /dev/null 2>&1; then
        echo "GPU test successful!"
    else
        echo "Warning: GPU test failed, but continuing setup..."
    fi

else
    echo "No NVIDIA GPU detected, skipping NVIDIA container toolkit installation"
fi

echo "Server setup completed!"
