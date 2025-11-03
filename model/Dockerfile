FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Install Python and system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    libsox-dev \
    sox \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip to latest version to avoid dependency resolution issues
RUN pip3 install --upgrade pip setuptools wheel

# Install PyTorch with CUDA 11.8 support (stable version)
RUN pip3 install --no-cache-dir \
    torch>=2.1.0 \
    torchvision \
    torchaudio \
    --index-url https://download.pytorch.org/whl/cu118

# Verify PyTorch installation
RUN python3 -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"

# Install dependencies step by step to avoid conflicts
# First install core dependencies
RUN pip3 install --no-cache-dir \
    huggingface_hub \
    transformers \
    accelerate \
    timm \
    einops \
    pillow \
    numpy

# Then install soxr (requires system libraries)
RUN pip3 install --no-cache-dir soxr

# Finally install lmdeploy with all extras
RUN pip3 install --no-cache-dir "lmdeploy[all]"

# Verify all dependencies are installed correctly
RUN python3 -c "import torch; import transformers; import timm; import einops; import lmdeploy; print('PyTorch:', torch.__version__); print('Transformers:', transformers.__version__); print('All dependencies OK')"

# Set working directory
WORKDIR /server/model

# Copy model preparation script
COPY model_prepare.py .

# Download the model during build (this might take a while)
RUN python3 model_prepare.py

# Expose port for the model service
EXPOSE 23333

# Command to run the model service using lmdeploy with GPU
# Use repo_id instead of hardcoded path - lmdeploy will automatically find it in cache
CMD ["lmdeploy", "serve", "api_server", "OpenGVLab/InternVL3-2B-AWQ", "--backend", "turbomind", "--server-port", "23333", "--model-format", "awq", "--cache-max-entry-count", "0.1", "--model-name", "internvl3-2b-awq"]