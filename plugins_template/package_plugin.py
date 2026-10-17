#!/usr/bin/env python3
"""
ApertureX Neural Forge — Plugin Packager
Validates manifest.json, calculates SHA-256 checksum, and packages plugin.zip.
"""

import hashlib
import json
import os
import sys
import zipfile

REQUIRED_FIELDS = ["plugin_id", "name", "author", "version", "task", "model_file", "input_shape"]
VALID_TASKS = ["depthEstimation", "subjectSegmentation", "portraitHair", "superResolution"]

def compute_sha256(filepath: str) -> str:
    sha = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            sha.update(chunk)
    return sha.hexdigest()

def package_plugin(directory: str = "."):
    manifest_path = os.path.join(directory, "manifest.json")
    if not os.path.exists(manifest_path):
        print(f"[Error] manifest.json not found in {directory}")
        sys.exit(1)

    with open(manifest_path, "r", encoding="utf-8") as f:
        try:
            manifest = json.load(f)
        except json.JSONDecodeError as e:
            print(f"[Error] Failed to parse manifest.json: {e}")
            sys.exit(1)

    for field in REQUIRED_FIELDS:
        if field not in manifest:
            print(f"[Error] Missing required field in manifest.json: '{field}'")
            sys.exit(1)

    if manifest["task"] not in VALID_TASKS:
        print(f"[Error] Invalid task: '{manifest['task']}'. Must be one of {VALID_TASKS}")
        sys.exit(1)

    model_file = manifest["model_file"]
    model_path = os.path.join(directory, model_file)
    if not os.path.exists(model_path):
        print(f"[Error] Specified model_file '{model_file}' not found in {directory}")
        sys.exit(1)

    sha256 = compute_sha256(model_path)
    file_size = os.path.getsize(model_path)
    manifest["sha256"] = sha256
    manifest["fileSizeBytes"] = file_size

    # Update manifest with checksum
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    zip_name = f"{manifest['plugin_id']}-v{manifest['version']}.zip"
    print(f"[*] Packaging plugin into {zip_name}...")
    with zipfile.ZipFile(zip_name, "w", zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(manifest_path, arcname="manifest.json")
        zipf.write(model_path, arcname=model_file)

    print(f"[✓] Successfully packaged {zip_name} ({file_size / (1024*1024):.2f} MB)")
    print(f"    SHA-256: {sha256}")
    print("\nYou can now upload this .zip to your GitHub Release or HuggingFace repo!")

if __name__ == "__main__":
    dir_to_package = sys.argv[1] if len(sys.argv) > 1 else "."
    package_plugin(dir_to_package)
