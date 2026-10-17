# ApertureX Neural Forge — Community AI Plugin Template

This directory provides the official template for building, testing, and distributing on-device AI plugins for **ApertureX**.

---

## 🌟 Why Build ApertureX Plugins?

ApertureX is the first mobile photo editor that allows users to install custom AI models via GitHub links or HuggingFace URLs. 
Because ApertureX executes ONNX models inside a sandboxed local runner on the user's phone, your plugin runs:
- **100% Offline & Private:** Zero cloud servers, zero API costs, zero data collection.
- **Fast:** Accelerated on mobile GPUs and NPUs.
- **Dynamic UI:** You define sliders in `manifest.json`; ApertureX automatically renders native Flutter sliders in the app!

---

## 📁 Repository Structure

```
plugins_template/
├── manifest.json         # Declarative manifest defining controls and tensor shapes
├── export_to_onnx.py     # Python script to convert PyTorch models to ONNX
├── package_plugin.py     # Packager script that validates and builds plugin.zip
└── README.md             # This guide
```

---

## 🚀 Step-by-Step Developer Guide

### 1. Choose Your Task & Model

ApertureX supports four primary model categories:

| Task Name | Output Tensor | Example Models |
|---|---|---|
| `depthEstimation` | 1×1×H×W (monocular depth) | Depth Anything V2, MiDaS, Marigold |
| `subjectSegmentation` | 1×1×H×W (alpha mask) | RMBG 1.4, MobileSAM, U²-Net |
| `portraitHair` | 1×1×H×W (hair alpha mask) | BiSeNet, MODNet |
| `superResolution` | 1×3×(2H)×(2W) (RGB image) | Real-ESRGAN Compact, NAFNet |

### 2. Export Your Model to ONNX

Use `export_to_onnx.py` or run:

```python
import torch

model.eval()
dummy = torch.randn(1, 3, 512, 512)
torch.onnx.export(
    model,
    dummy,
    "model.onnx",
    opset_version=17,
    input_names=["input_image"],
    output_names=["output_tensor"],
)
```

### 3. Customize `manifest.json`

Define the sliders you want to show up in the ApertureX editor:

```json
{
  "plugin_id": "com.yourname.bokeh_pro",
  "name": "Bokeh Pro Depth",
  "author": "Your Name / GitHub",
  "version": "1.0.0",
  "task": "depthEstimation",
  "model_file": "model.onnx",
  "input_shape": [1, 3, 512, 512],
  "controls": [
    {
      "id": "blur_radius",
      "label": "Lens Aperture (F-Stop)",
      "type": "slider",
      "min": 0.0,
      "max": 100.0,
      "default": 35.0
    }
  ]
}
```

### 4. Package & Publish

Run the packager script:

```bash
python package_plugin.py .
```

This verifies the files, computes the SHA-256 integrity hash, and outputs:
`com.yourname.bokeh_pro-v1.0.0.zip`

### 5. Distribute to Users

Upload your `.zip` to a **GitHub Release** or **HuggingFace model repository**.

Users simply go to:
**Settings → AI Models & Plugins → Add Plugin → Paste your GitHub Link**

The app automatically downloads the model, verifies the SHA-256 checksum, and adds your custom sliders directly to the editor!
