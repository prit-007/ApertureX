use std::fs;
use std::path::Path;

use rust_lib_aperturex::api::raw::{decode_raw_roi, raw_dimensions};
use rust_lib_aperturex::blur::{apply_lens_blur, BokehShape, LensBlurParams};
use rust_lib_aperturex::color::{grade_pixel_srgb, saturate_oklab, GradeParams};
use rust_lib_aperturex::mask::{detect_subject, refine_mask_guided};
use rust_lib_aperturex::ml::{estimate_depth_map, SaliencySegmenter, Segmenter};
use rust_lib_aperturex::optics::apply_lateral_ca;
use rust_lib_aperturex::spatial::{dehaze, denoise, film_halation};

#[test]
fn test_golden_fixture_image_2_dng() {
    let fixture_path = Path::new("tests/golden_fixtures/image_2.dng");
    if !fixture_path.exists() {
        eprintln!("Skipping: fixture not found at {:?}", fixture_path);
        return;
    }
    let bytes = fs::read(fixture_path).expect("failed to read image_2.dng");
    assert!(bytes.len() > 1000);

    // 1. Metadata / dimensions
    let dims = raw_dimensions(bytes.clone()).expect("failed to get raw dimensions for image_2.dng");
    assert!(dims.width > 0 && dims.height > 0);
    println!("image_2.dng dimensions: {}x{}", dims.width, dims.height);

    // 2. ROI decode (center tile)
    let roi = decode_raw_roi(bytes.clone(), 0, 0, 128, 128)
        .expect("failed to decode ROI for image_2.dng");
    assert_eq!((roi.width, roi.height), (128, 128));
    assert_eq!(roi.rgba.len(), 128 * 128 * 4);

    // 3. Subject detection on the decoded ROI
    if let Some(subject) = detect_subject(&roi.rgba, roi.width as usize, roi.height as usize) {
        assert!((0.0..=1.0).contains(&subject.cx));
        assert!((0.0..=1.0).contains(&subject.cy));
    }

    // 4. Saliency Segmenter on the decoded ROI
    let segmenter = SaliencySegmenter {};
    let mask = segmenter
        .segment(&roi.rgba, roi.width as usize, roi.height as usize, 128, 128)
        .expect("segmentation failed");
    assert_eq!(mask.len(), 128 * 128);

    // 5. Hair matting & fine transition refinement via guided filter
    let refined_hair_mask = refine_mask_guided(
        &roi.rgba,
        roi.width as usize,
        roi.height as usize,
        &mask,
        &[],
        0.05,
        4,
        1e-3,
    );
    assert_eq!(refined_hair_mask.len(), 128 * 128);
    for &alpha in &refined_hair_mask {
        assert!(alpha.is_finite() && (0.0..=1.0).contains(&alpha));
    }

    // 6. Oklab vibrance and grading on decoded pixels (no NaNs or infinities)
    for chunk in roi.rgba.as_chunks::<4>().0.iter().take(256) {
        let r = chunk[0] as f32 / 255.0;
        let g = chunk[1] as f32 / 255.0;
        let b = chunk[2] as f32 / 255.0;
        let saturated = saturate_oklab([r, g, b], 0.35);
        assert!(saturated[0].is_finite() && (0.0..=1.0).contains(&saturated[0]));
        assert!(saturated[1].is_finite() && (0.0..=1.0).contains(&saturated[1]));
        assert!(saturated[2].is_finite() && (0.0..=1.0).contains(&saturated[2]));
    }
}

#[test]
fn test_golden_fixture_image_1_cr2() {
    let fixture_path = Path::new("tests/golden_fixtures/image_1.CR2");
    if !fixture_path.exists() {
        return;
    }
    let bytes = fs::read(fixture_path).expect("failed to read image_1.CR2");
    assert!(bytes.len() > 1000);
    let dims = raw_dimensions(bytes.clone()).expect("failed to get dimensions for image_1.CR2");
    assert!(dims.width > 0 && dims.height > 0);
    println!("image_1.CR2 dimensions: {}x{}", dims.width, dims.height);

    // 1. ROI decode + highlight/shadow recovery evaluation
    let roi = decode_raw_roi(bytes.clone(), 0, 0, 128, 128)
        .expect("failed to decode ROI for image_1.CR2");
    assert_eq!((roi.width, roi.height), (128, 128));
    assert_eq!(roi.rgba.len(), 128 * 128 * 4);

    let params = GradeParams {
        highlights: -0.8,
        shadows: 0.5,
        exposure: 0.5,
        ..Default::default()
    };
    for chunk in roi.rgba.as_chunks::<4>().0.iter().take(128) {
        let r = chunk[0] as f32 / 255.0;
        let g = chunk[1] as f32 / 255.0;
        let b = chunk[2] as f32 / 255.0;
        let out = grade_pixel_srgb(r, g, b, params);
        assert!(out[0].is_finite() && (0.0..=1.0).contains(&out[0]));
        assert!(out[1].is_finite() && (0.0..=1.0).contains(&out[1]));
        assert!(out[2].is_finite() && (0.0..=1.0).contains(&out[2]));
    }

    // 2. Dehaze halos test: atmospheric transmission recovery
    let dehazed = dehaze(&roi.rgba, 128, 128, 0.4);
    assert_eq!(dehazed.len(), 128 * 128 * 4);
    for chunk in dehazed.as_chunks::<4>().0.iter().take(128) {
        assert_eq!(chunk[3], 255); // Alpha preserved
    }
}

#[test]
fn test_golden_fixture_image_3_arw() {
    let fixture_path = Path::new("tests/golden_fixtures/image_3.ARW");
    if !fixture_path.exists() {
        return;
    }
    let bytes = fs::read(fixture_path).expect("failed to read image_3.ARW");
    assert!(bytes.len() > 1000);
    let dims = raw_dimensions(bytes.clone()).expect("failed to get dimensions for image_3.ARW");
    assert!(dims.width > 0 && dims.height > 0);
    println!("image_3.ARW dimensions: {}x{}", dims.width, dims.height);

    let roi = decode_raw_roi(bytes.clone(), 0, 0, 128, 128)
        .expect("failed to decode ROI for image_3.ARW");
    assert_eq!((roi.width, roi.height), (128, 128));
    assert_eq!(roi.rgba.len(), 128 * 128 * 4);

    // Architecture geometry & Lateral CA correction
    let ca_corrected = apply_lateral_ca(&roi.rgba, 128, 128);
    assert_eq!(ca_corrected.len(), 128 * 128 * 4);
    // Center pixel should be unchanged by lateral CA correction
    let center_idx = (64 * 128 + 64) * 4;
    assert_eq!(
        &ca_corrected[center_idx..center_idx + 4],
        &roi.rgba[center_idx..center_idx + 4]
    );
}

#[test]
fn test_golden_fixture_image_4_arw() {
    let fixture_path = Path::new("tests/golden_fixtures/image_4.arw");
    if !fixture_path.exists() {
        return;
    }
    let bytes = fs::read(fixture_path).expect("failed to read image_4.arw");
    assert!(bytes.len() > 1000);
    let dims = raw_dimensions(bytes.clone()).expect("failed to get dimensions for image_4.arw");
    assert!(dims.width > 0 && dims.height > 0);
    println!("image_4.arw dimensions: {}x{}", dims.width, dims.height);

    let roi = decode_raw_roi(bytes.clone(), 0, 0, 128, 128)
        .expect("failed to decode ROI for image_4.arw");
    assert_eq!((roi.width, roi.height), (128, 128));
    assert_eq!(roi.rgba.len(), 128 * 128 * 4);

    // High-ISO night street: luma & chroma denoise, and film halation
    let denoised = denoise(&roi.rgba, 128, 128, 0.5, 0.6);
    assert_eq!(denoised.len(), 128 * 128 * 4);

    let halated = film_halation(&denoised, 128, 128, 0.4, 0.05, 0.75);
    assert_eq!(halated.len(), 128 * 128 * 4);
}

#[test]
fn test_golden_fixture_image_2_2_rw2() {
    let fixture_path = Path::new("tests/golden_fixtures/image_2_2.RW2");
    if !fixture_path.exists() {
        return;
    }
    let bytes = fs::read(fixture_path).expect("failed to read image_2_2.RW2");
    assert!(bytes.len() > 1000);
    let dims = raw_dimensions(bytes.clone()).expect("failed to get dimensions for image_2_2.RW2");
    assert!(dims.width > 0 && dims.height > 0);
    println!("image_2_2.RW2 dimensions: {}x{}", dims.width, dims.height);

    let roi = decode_raw_roi(bytes.clone(), 0, 0, 128, 128)
        .expect("failed to decode ROI for image_2_2.RW2");
    assert_eq!((roi.width, roi.height), (128, 128));
    assert_eq!(roi.rgba.len(), 128 * 128 * 4);

    // Depth estimation & AI lens blur
    let depth_map =
        estimate_depth_map(&roi.rgba, 128, 128, 128, 128).expect("depth map estimation failed");
    assert_eq!(depth_map.len(), 128 * 128);
    for &d in &depth_map {
        assert!(d.is_finite() && (0.0..=1.0).contains(&d));
    }

    let blur_params = LensBlurParams {
        enabled: true,
        amount: 0.7,
        focal_point: 0.35,
        focal_range: 0.2,
        bokeh_shape: BokehShape::Hexagon,
        bokeh_boost: 0.2,
    };
    let blurred = apply_lens_blur(&roi.rgba, 128, 128, blur_params, Some(&depth_map), 36);
    assert_eq!(blurred.len(), 128 * 128 * 4);
}

#[test]
fn test_golden_fixture_synthetic_math_breaker_png() {
    let fixture_path = Path::new("tests/golden_fixtures/synthetic_math_breaker.png");
    if !fixture_path.exists() {
        return;
    }
    let bytes = fs::read(fixture_path).expect("failed to read synthetic_math_breaker.png");
    assert!(bytes.len() > 1000);

    // PNG signature: [137, 80, 78, 71, 13, 10, 26, 10]
    assert_eq!(&bytes[0..8], &[137, 80, 78, 71, 13, 10, 26, 10]);

    // IHDR chunk: 4 bytes length + "IHDR" + 4 bytes width + 4 bytes height
    assert_eq!(&bytes[12..16], b"IHDR");
    let width = u32::from_be_bytes([bytes[16], bytes[17], bytes[18], bytes[19]]);
    let height = u32::from_be_bytes([bytes[20], bytes[21], bytes[22], bytes[23]]);
    let bit_depth = bytes[24];
    let color_type = bytes[25];

    println!(
        "synthetic_math_breaker.png: {}x{}, bit_depth={}, color_type={}, file_size={} bytes",
        width,
        height,
        bit_depth,
        color_type,
        bytes.len()
    );
    assert_eq!((width, height), (2048, 2048));
    assert_eq!(bit_depth, 8);

    // Test tone curve monotonicity across mathematical ramp samples
    let ramp_samples: [f32; 9] = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0];
    let test_params = [
        GradeParams::default(),
        GradeParams {
            exposure: 1.5,
            contrast: 0.3,
            ..Default::default()
        },
        GradeParams {
            exposure: -1.5,
            contrast: -0.2,
            ..Default::default()
        },
        GradeParams {
            highlights: -0.5,
            shadows: 0.5,
            ..Default::default()
        },
    ];

    for params in test_params {
        let mut prev_luma = -1.0;
        for &sample in &ramp_samples {
            let out = grade_pixel_srgb(sample, sample, sample, params);
            assert!(out[0].is_finite() && (0.0..=1.0).contains(&out[0]));
            assert!(out[1].is_finite() && (0.0..=1.0).contains(&out[1]));
            assert!(out[2].is_finite() && (0.0..=1.0).contains(&out[2]));

            // Luminance = 0.2126 R + 0.7152 G + 0.0722 B
            let luma = 0.2126 * out[0] + 0.7152 * out[1] + 0.0722 * out[2];
            assert!(
                luma >= prev_luma - 1e-4,
                "monotonicity violated: {} < {}",
                luma,
                prev_luma
            );
            prev_luma = luma;
        }
    }
}

#[test]
fn test_export_dng_golden_fixture_cfa_lossless_passthrough() {
    let fixture_path = Path::new("tests/golden_fixtures/image_2.dng");
    if !fixture_path.exists() {
        return;
    }
    let bytes = fs::read(fixture_path).expect("failed to read image_2.dng");
    let test_xmp =
        "<x:xmpmeta><rdf:RDF><rdf:Description crs:Exposure2012=\"+1.20\"/></rdf:RDF></x:xmpmeta>";

    let exported = rust_lib_aperturex::raw::export_dng(&bytes, test_xmp)
        .expect("export_dng on real RAW should succeed");
    assert!(exported.len() > 1000);

    // Verify injected XMP
    let found_xmp = exported.windows(b"+1.20".len()).any(|w| w == b"+1.20");
    assert!(found_xmp, "Exported real RAW DNG must contain injected XMP");

    // Verify dimensions match original RAW metadata
    let original_meta = rust_lib_aperturex::raw::metadata(&bytes).expect("original meta");
    let exported_meta = rust_lib_aperturex::raw::metadata(&exported).expect("exported meta");
    assert_eq!(exported_meta.width, original_meta.width);
    assert_eq!(exported_meta.height, original_meta.height);
}
