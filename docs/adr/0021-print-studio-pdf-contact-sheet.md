# ADR 0021 — Print Studio & Contact Sheet PDF Pipeline

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0004 (GPLv3 & F-Droid Distribution), ADR 0020 (Soft Proofing & Gamut Mapping)

---

## 1. Context

Professional photographers require print-ready deliverables and proofing materials directly from their mobile and desktop photo editing suites:
- **Contact Sheets**: Essential for client reviews, model agencies, and lab proofs, presenting multi-image grid sheets with metadata annotations (filenames, EXIF exposure data, dates).
- **Single Photo Print Layouts**: Custom paper sizing (A4, A3, US Letter, US Legal, Postcard 4×6, 5×7, 8×10, 11×14, Super B 13×19), millimeter-accurate margin guides, and page alignment.
- **Color Accuracy**: Seamless integration with soft-proofing profiles (sRGB, Display P3, Adobe RGB, CMYK SWOP) and rendering intents.
- **Privacy & FOSS Compliance**: Standard mobile print packages often depend on proprietary cloud rendering or heavy C++ binaries with license incompatibilities. ApertureX must generate print PDFs completely offline with zero tracking and zero external network calls.

## 2. Decision

Implement an offline, pure-Dart binary PDF 1.4 document generator and interactive WYSIWYG Print Studio:

1. **Pure Dart Binary PDF 1.4 Engine (`print_pdf_generator.dart`)**:
   - Compiles compliant multi-page PDF 1.4 documents from scratch without third-party PDF dependencies.
   - Embeds full-fidelity images directly using standard `/DCTDecode` streams to avoid lossy recompression artifacts and maintain embedded ICC color profiles.
   - Draws vector margin guides, cell boundary strokes, pagination (`- Page X -`), and Helvetica metadata captions.

2. **Contact Sheet & Single Layout Models (`print_model.dart`)**:
   - `PaperSize`: Dimension tables in millimeters and 72-point PostScript coordinates.
   - `PrintMargins`: Millimeter-accurate margins calculating printable bounding boxes.
   - `ContactSheetGrid`: Dynamic row/column calculation, cell bounding boxes, and multi-page pagination.
   - `PrintColorManagement`: Direct integration with `ProofProfile` and `ProofIntent` from ADR 0020.

3. **Interactive WYSIWYG Print Studio Screen (`print_screen.dart`)**:
   - Live paper canvas preview simulating paper aspect ratio, margin guidelines, photo cell layout, and soft-proof paper tint.
   - Real-time Gamut Warning badge overlay.
   - Pro inspector controls for paper setup, layout grid dimensions, cell borders, and caption metadata toggles.
   - Instant "Export PDF" generation.

## 3. Consequences

### Positive
- **100% Offline & F-Droid Compliant**: Zero external dependencies, pure Dart implementation.
- **Lossless Quality**: Full-resolution JPEGs stream directly into the PDF without degradation.
- **Studio Workflow Parity**: Matches Lightroom Classic's Print module and Contact Sheet layout capabilities.

### Negative
- Pure Dart PDF generation is intentionally limited to PDF 1.4 features (vector borders, text captions, and DCT image streams); complex interactive forms or CMYK vector separations are left to downstream RIP software.
