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

    if os.path.exists(model_path):
        print("Model already exists, skipping download")
        return

    print("Downloading InternVL3-2B-AWQ model...")

    try:
        # Download the model
        snapshot_download(
            repo_id="OpenGVLab/InternVL3-2B-AWQ",
            local_dir=model_path,
            local_dir_use_symlinks=False
        )
        print("Model downloaded successfully")

    except Exception as e:
        print(f"Error downloading model: {e}")
        sys.exit(1)

if __name__ == "__main__":
    download_model()
