#!/usr/bin/env python3
"""
ApertureX Neural Forge — Model Exporter
Converts PyTorch and HuggingFace models to mobile-ready ONNX format.
"""

import sys
import torch
import torch.nn as nn

def export_model_to_onnx(model: nn.Module, output_path: str = "model.onnx", input_dim: int = 512):
    model.eval()
    dummy_input = torch.randn(1, 3, input_dim, input_dim, requires_grad=False)

    print(f"[*] Exporting PyTorch model to ONNX: {output_path} (input: 1x3x{input_dim}x{input_dim})...")
    torch.onnx.export(
        model,
        dummy_input,
        output_path,
        export_params=True,
        opset_version=17,
        do_constant_folding=True,
        input_names=["input_image"],
        output_names=["output_tensor"],
        dynamic_axes=None,  # Fixed shape recommended for mobile NPU/GPU speed
    )
    print(f"[✓] Successfully exported {output_path}")

    # Verify ONNX model with onnxruntime
    try:
        import onnx
        import onnxruntime as ort

        onnx_model = onnx.load(output_path)
        onnx.checker.check_model(onnx_model)
        session = ort.InferenceSession(output_path, providers=["CPUExecutionProvider"])
        outputs = session.run(None, {"input_image": dummy_input.numpy()})
        print(f"[✓] ONNX validation passed! Output shape: {outputs[0].shape}")
    except ImportError:
        print("[!] Install onnx and onnxruntime to verify exports: pip install onnx onnxruntime")

if __name__ == "__main__":
    print("ApertureX ONNX Exporter Template")
    print("Usage: import export_model_to_onnx in your model training/inference script.")
