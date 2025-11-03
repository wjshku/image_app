#!/usr/bin/env python3
"""
Model preparation script for InternVL3-2B-AWQ
Downloads and prepares the model for deployment
"""

import os
import sys
from huggingface_hub import snapshot_download

def download_model():
    """Download InternVL3-2B-AWQ model from HuggingFace"""
    model_path = "/root/.cache/huggingface/hub/models--OpenGVLab--InternVL3-2B-AWQ"
    
    # Check if model is already downloaded by checking snapshots subdirectory
    snapshots_path = os.path.join(model_path, "snapshots")
    if os.path.exists(snapshots_path) and os.listdir(snapshots_path):
        print("Model already exists in cache, skipping download")
        print(f"Found model at: {snapshots_path}")
        return

    print("Downloading InternVL3-2B-AWQ model from HuggingFace...")
    print("This may take a while depending on your network speed...")

    try:
        # Download the model
        snapshot_download(
            repo_id="OpenGVLab/InternVL3-2B-AWQ",
            local_dir=model_path,
            local_dir_use_symlinks=False,
            resume_download=True  # Resume if interrupted
        )
        
        # Verify download
        if os.path.exists(snapshots_path) and os.listdir(snapshots_path):
            print("Model downloaded successfully")
            print(f"Model saved to: {snapshots_path}")
        else:
            raise Exception("Download completed but model files not found")
            
    except KeyboardInterrupt:
        print("\nDownload interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Error downloading model: {e}")
        print(f"Model path: {model_path}")
        print("Please check your network connection and try again")
        sys.exit(1)

if __name__ == "__main__":
    download_model()
