# ApertureX Look QR Open Standard Specification (v1)

- **Status:** Standard / Active
- **Date:** 2026-10-17
- **Authority:** ApertureX Core Engine Team (ADR 0009 follow-up)
- **License:** Open Standard (CC0 / Public Domain)

---

## 1. Abstract

The ApertureX Look QR Open Standard defines an open, vendor-neutral, portable format for encoding, sharing, and scanning non-destructive photo editing looks across mobile devices, social platforms, and print media without proprietary binary blobs or cloud lock-in.

---

## 2. Core Principles

1. **Open & Self-Describing:** Anyone can parse and render the format with standard JSON and zlib/deflate tools. No proprietary encryption, vendor signatures, or licensing fees.
2. **Sparse Parameter Efficiency:** Only non-neutral parameter deviations from the identity state are serialized. Neutral values (`0.0`, empty curves, default geometry) are omitted.
3. **Small Optical Footprint:** Payload sizes typically range from 150 to 350 bytes, enabling high-density QR versions (Version 4 to 6) with High (H, 30%) error correction for instant scanning even under poor lighting, screen reflections, or perspective distortion.
4. **Forward and Backward Compatibility:** Unrecognized keys or parameters introduced in future schema versions are safely ignored without failing the import.

---

## 3. Protocol & URI Scheme

An ApertureX Look QR payload can be represented in either of two modes:

### 3.1. URI Format (Preferred for QR Codes)

```
apx://look/v1?name=<URL_ENCODED_NAME>&author=<URL_ENCODED_AUTHOR>&data=<BASE64URL_COMPRESSED_PAYLOAD>
```

- **Scheme:** `apx:`
- **Host / Path:** `look/v1`
- **Query Parameters:**
  - `name`: Human-readable title of the look (e.g. `Portra+400`).
  - `author`: Optional creator handle or name (e.g. `@alex`).
  - `data`: Base64URL-encoded (RFC 4648 §5, no padding) `zlib.deflate` compressed UTF-8 JSON payload.
  - `raw`: (Optional) If payload is uncompressed JSON, URL-encoded raw JSON string.

### 3.2. Direct JSON Object Format (Preferred for Files & EXIF)

For `.aperturex.json` files and embedded EXIF `UserComment` tags:

```json
{
  "$schema": "https://aperturex.app/schema/look-v1.json",
  "v": 1,
  "name": "Cinematic Teal & Orange",
  "author": "@devparadise",
  "description": "Punchy shadows with warm skin tones",
  "params": {
    "exposure": 0.15,
    "contrast": 0.20,
    "highlights": -0.25,
    "shadows": 0.18,
    "temperature": 0.10,
    "vibrance": 0.15,
    "clarity": 0.10,
    "grain": 0.15,
    "filmHalation": 0.20,
    "gradeShadowHue": 195.0,
    "gradeShadowSat": 0.35,
    "gradeHighlightHue": 38.0,
    "gradeHighlightSat": 0.25
  },
  "curves": {
    "master": [
      [0.0, 0.04],
      [0.25, 0.20],
      [0.75, 0.80],
      [1.0, 0.96]
    ]
  }
}
```

---

## 4. Parameter Mapping & Shorthand Notation

To further optimize payload size in high-density QR codes, parameter keys may optionally use documented 3-to-4 character abbreviations:

| Shorthand | Canonical Parameter | Description |
| :--- | :--- | :--- |
| `exp` | `exposure` | Exposure in EV (-5.0 to +5.0) |
| `con` | `contrast` | Contrast (-1.0 to +1.0) |
| `high` | `highlights` | Highlights (-1.0 to +1.0) |
| `shad` | `shadows` | Shadows (-1.0 to +1.0) |
| `whi` | `whites` | Whites (-1.0 to +1.0) |
| `bla` | `blacks` | Blacks (-1.0 to +1.0) |
| `temp` | `temperature` | White balance temperature (-1.0 to +1.0) |
| `tint` | `tint` | White balance tint (-1.0 to +1.0) |
| `vib` | `vibrance` | Skin-preserving vibrance (-1.0 to +1.0) |
| `sat` | `saturation` | Global saturation (-1.0 to +1.0) |
| `cla` | `clarity` | Local contrast / clarity (-1.0 to +1.0) |
| `tex` | `texture` | High-frequency texture (-1.0 to +1.0) |
| `deh` | `dehaze` | Dehaze (-1.0 to +1.0) |
| `vig` | `vignette` | Radial vignette (-1.0 to +1.0) |
| `gra` | `grain` | Film grain intensity (0.0 to 1.0) |
| `sha` | `sharpen` | Detail sharpening (0.0 to 1.0) |
| `hal` | `filmHalation` | Film halation intensity (0.0 to 1.0) |
| `blo` | `filmBloom` | Optical bloom intensity (0.0 to 1.0) |
| `gsh` | `gradeShadowHue` | Shadow grading hue (0° to 360°) |
| `gss` | `gradeShadowSat` | Shadow grading saturation (0.0 to 1.0) |
| `gsl` | `gradeShadowLum` | Shadow grading luminance (-1.0 to +1.0) |
| `gmh` | `gradeMidHue` | Midtone grading hue (0° to 360°) |
| `gms` | `gradeMidSat` | Midtone grading saturation (0.0 to 1.0) |
| `gml` | `gradeMidLum` | Midtone grading luminance (-1.0 to +1.0) |
| `ghh` | `gradeHighlightHue` | Highlight grading hue (0° to 360°) |
| `ghs` | `gradeHighlightSat` | Highlight grading saturation (0.0 to 1.0) |
| `ghl` | `gradeHighlightLum` | Highlight grading luminance (-1.0 to +1.0) |

The decoder MUST accept both canonical full names and shorthand keys interchangeably.

---

## 5. Error Correction & Optical Quality Gates

- **Minimum Error Correction:** Level M (15% recovery) for digital display; Level Q (25%) or Level H (30%) for social media posts, print, and stickers.
- **Minimum Resolution for Export:** 300x300 px rendering for the QR matrix with a 4-module quiet zone of pure white (`#FFFFFF`) or high-contrast background.
- **Steganography Fallback:** Image cards exported with embedded QR codes SHOULD also embed the raw JSON in the JPEG EXIF `UserComment` or PNG `tEXt` chunk so that direct file sharing does not depend on camera or optical recognition.
