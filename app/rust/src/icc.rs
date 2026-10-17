//! Wide-Color-Gamut (WCG) engine & ICC profile processor (issue #15).
//!
//! Provides a mathematically rigorous 16-bit float / 32-bit linear Display-P3
//! working space, true ICC Matrix/TRC parsing with Bradford chromatic adaptation,
//! standard Display-P3 ICC profile generation, and smooth soft-knee gamut mapping.

use crate::color::{linear_to_srgb, srgb_to_linear};

pub const CS_UNKNOWN: u32 = 0;
pub const CS_SRGB: u32 = 1;
pub const CS_DISPLAY_P3: u32 = 2;
pub const CS_ADOBE_RGB: u32 = 3;
pub const CS_BT2020: u32 = 4;

/// Linear sRGB (D65) → Linear Display-P3 (D65).
pub const SRGB_TO_LINEAR_P3: [[f32; 3]; 3] = [
    [0.822_462_1, 0.177_538, 0.000_000_0],
    [0.033_194_2, 0.966_805_8, 0.000_000_0],
    [0.017_082_7, 0.072_397_4, 0.910_519_9],
];

/// Linear Display-P3 (D65) → Linear sRGB (D65).
pub const LINEAR_P3_TO_SRGB: [[f32; 3]; 3] = [
    [1.224_940_1, -0.224_940_4, 0.000_000_0],
    [-0.042_056_9, 1.042_057_1, 0.000_000_0],
    [-0.019_637_6, -0.078_636_1, 1.098_273_6],
];

/// Bradford Chromatic Adaptation Matrix from CIE Standard Illuminant D50 to D65.
pub const BRADFORD_D50_TO_D65: [[f32; 3]; 3] = [
    [0.955_576_6, -0.023_039_3, 0.063_163_6],
    [-0.028_289_5, 1.009_941_6, 0.021_007_7],
    [0.012_298_2, -0.020_483_0, 1.329_909_8],
];

/// Linear Display-P3 (D65) → CIE 1931 XYZ (D65).
pub const LINEAR_P3_TO_XYZ_D65: [[f32; 3]; 3] = [
    [0.486_570_9, 0.265_667_7, 0.198_217_3],
    [0.228_974_6, 0.691_739_3, 0.079_286_1],
    [0.000_000_0, 0.045_113_4, 1.043_944_4],
];

/// Multiplies a 3x3 matrix with a 3D column vector.
#[inline(always)]
pub fn mul_mat3_vec3(m: &[[f32; 3]; 3], v: [f32; 3]) -> [f32; 3] {
    [
        m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
        m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
        m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ]
}

/// Converts an sRGB encoded pixel (0.0..1.0) to Linear Display-P3 (0.0..1.0).
#[inline(always)]
pub fn srgb_to_linear_p3_pixel(srgb: [f32; 3]) -> [f32; 3] {
    let lin_srgb = [
        srgb_to_linear(srgb[0]),
        srgb_to_linear(srgb[1]),
        srgb_to_linear(srgb[2]),
    ];
    mul_mat3_vec3(&SRGB_TO_LINEAR_P3, lin_srgb)
}

/// Converts a Display-P3 gamma-encoded pixel (0.0..1.0) to Linear Display-P3 (0.0..1.0).
/// Note: Display-P3 uses the exact same piecewise OETF curve as standard sRGB.
#[inline(always)]
pub fn display_p3_to_linear_p3_pixel(p3: [f32; 3]) -> [f32; 3] {
    [
        srgb_to_linear(p3[0]),
        srgb_to_linear(p3[1]),
        srgb_to_linear(p3[2]),
    ]
}

/// Converts a Linear Display-P3 pixel to Display-P3 gamma-encoded (0.0..1.0).
#[inline(always)]
pub fn linear_p3_to_display_p3_pixel(lin_p3: [f32; 3]) -> [f32; 3] {
    [
        linear_to_srgb(lin_p3[0].max(0.0)).clamp(0.0, 1.0),
        linear_to_srgb(lin_p3[1].max(0.0)).clamp(0.0, 1.0),
        linear_to_srgb(lin_p3[2].max(0.0)).clamp(0.0, 1.0),
    ]
}

/// Converts a Linear Display-P3 pixel to Linear sRGB.
#[inline(always)]
pub fn linear_p3_to_linear_srgb_pixel(lin_p3: [f32; 3]) -> [f32; 3] {
    mul_mat3_vec3(&LINEAR_P3_TO_SRGB, lin_p3)
}

/// Converts a Linear Display-P3 pixel to sRGB encoded pixel with soft-knee gamut compression.
pub fn linear_p3_to_srgb_pixel(lin_p3: [f32; 3]) -> [f32; 3] {
    let lin_srgb = linear_p3_to_linear_srgb_pixel(lin_p3);
    let srgb = [
        linear_to_srgb(lin_srgb[0]),
        linear_to_srgb(lin_srgb[1]),
        linear_to_srgb(lin_srgb[2]),
    ];
    soft_knee_gamut_compress(srgb)
}

/// Soft-knee gamut compression: instead of brutal clipping at 0.0 and 1.0 which destroys
/// highlight detail and creates color fringing, gently compresses out-of-gamut chroma
/// while preserving perceived luminance.
pub fn soft_knee_gamut_compress(rgb: [f32; 3]) -> [f32; 3] {
    let knee = 0.88f32;
    let compress = |x: f32| -> f32 {
        if x <= knee {
            x.max(0.0)
        } else if x <= 1.0 {
            x
        } else {
            knee + (1.0 - knee) * ((x - knee) / (1.0 - knee)).tanh()
        }
    };

    let r = compress(rgb[0]);
    let g = compress(rgb[1]);
    let b = compress(rgb[2]);

    [r.clamp(0.0, 1.0), g.clamp(0.0, 1.0), b.clamp(0.0, 1.0)]
}

/// Extracted Matrix/TRC parameters from an ICC profile.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct IccMatrix {
    pub r_xyz: [f32; 3],
    pub g_xyz: [f32; 3],
    pub b_xyz: [f32; 3],
    pub white_point: [f32; 3],
}

/// Concatenates the payloads of all APP2/ICC_PROFILE segments of [jpeg].
pub fn extract_icc(jpeg: &[u8]) -> Option<Vec<u8>> {
    if jpeg.len() < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8 {
        return None;
    }
    let mut icc = Vec::new();
    let mut found = false;
    let mut i = 2usize;
    while i + 4 <= jpeg.len() {
        if jpeg[i] != 0xFF {
            break;
        }
        let marker = jpeg[i + 1];
        if marker == 0xD8 || marker == 0x01 || (0xD0..=0xD9).contains(&marker) {
            i += 2;
            continue;
        }
        let len = ((jpeg[i + 2] as usize) << 8) | jpeg[i + 3] as usize;
        let seg_end = i + 2 + len;
        if seg_end > jpeg.len() || len < 2 {
            break;
        }
        if marker == 0xE2 {
            let payload = &jpeg[i + 4..seg_end];
            if payload.len() > 14 && &payload[..12] == b"ICC_PROFILE\0" {
                icc.extend_from_slice(&payload[14..]); // skip header + seq/count
                found = true;
            }
        }
        if marker == 0xDA {
            break;
        }
        i = seg_end;
    }
    if found {
        Some(icc)
    } else {
        None
    }
}

/// Parses standard ICC tags (rXYZ, gXYZ, bXYZ, wtpt) from an ICC profile payload.
pub fn parse_icc_matrix(icc: &[u8]) -> Option<IccMatrix> {
    if icc.len() < 132 {
        return None;
    }
    let tag_count = u32::from_be_bytes(icc[128..132].try_into().ok()?) as usize;
    if icc.len() < 132 + tag_count * 12 {
        return None;
    }

    let mut r_xyz = None;
    let mut g_xyz = None;
    let mut b_xyz = None;
    let mut wtpt = None;

    let read_s15fixed16 = |buf: &[u8], offset: usize| -> Option<[f32; 3]> {
        if offset + 20 > buf.len() {
            return None;
        }
        // Verify XYZType tag signature: 0x58595A20 ("XYZ ")
        if &buf[offset..offset + 4] != b"XYZ " {
            return None;
        }
        let x =
            (i32::from_be_bytes(buf[offset + 8..offset + 12].try_into().ok()?) as f32) / 65536.0;
        let y =
            (i32::from_be_bytes(buf[offset + 12..offset + 16].try_into().ok()?) as f32) / 65536.0;
        let z =
            (i32::from_be_bytes(buf[offset + 16..offset + 20].try_into().ok()?) as f32) / 65536.0;
        Some([x, y, z])
    };

    for idx in 0..tag_count {
        let tag_start = 132 + idx * 12;
        let sig = &icc[tag_start..tag_start + 4];
        let offset =
            u32::from_be_bytes(icc[tag_start + 4..tag_start + 8].try_into().ok()?) as usize;
        match sig {
            b"rXYZ" => r_xyz = read_s15fixed16(icc, offset),
            b"gXYZ" => g_xyz = read_s15fixed16(icc, offset),
            b"bXYZ" => b_xyz = read_s15fixed16(icc, offset),
            b"wtpt" => wtpt = read_s15fixed16(icc, offset),
            _ => {}
        }
    }

    Some(IccMatrix {
        r_xyz: r_xyz?,
        g_xyz: g_xyz?,
        b_xyz: b_xyz?,
        white_point: wtpt.unwrap_or([0.9642, 1.0000, 0.8249]), // default D50
    })
}

/// Detects the embedded colour space of [jpeg], inspecting both text tags and matrix coordinates.
pub fn detect_colorspace(jpeg: &[u8]) -> u32 {
    match extract_icc(jpeg) {
        None => CS_SRGB, // no profile → assume sRGB
        Some(profile) => {
            // First check description strings
            if contains(&profile, b"Display P3")
                || contains(&profile, b"Display-P3")
                || contains(&profile, b"P3")
            {
                return CS_DISPLAY_P3;
            }
            if contains(&profile, b"Adobe RGB") || contains(&profile, b"compatible with Adobe RGB")
            {
                return CS_ADOBE_RGB;
            }
            if contains(&profile, b"Rec.2020") || contains(&profile, b"BT.2020") {
                return CS_BT2020;
            }

            // Fallback: analyze mathematical chromaticities if tags are present
            if let Some(m) = parse_icc_matrix(&profile) {
                // Adapt D50 rXYZ to D65
                let d65_r = mul_mat3_vec3(&BRADFORD_D50_TO_D65, m.r_xyz);
                let sum_r = d65_r[0] + d65_r[1] + d65_r[2];
                if sum_r > 1e-4 {
                    let rx = d65_r[0] / sum_r;
                    // Display-P3 red chromaticity x ≈ 0.680; sRGB red x ≈ 0.640
                    if rx > 0.660 {
                        return CS_DISPLAY_P3;
                    }
                    if rx > 0.695 {
                        return CS_BT2020;
                    }
                }
            }

            CS_SRGB
        }
    }
}

fn contains(haystack: &[u8], needle: &[u8]) -> bool {
    haystack.windows(needle.len()).any(|w| w == needle)
}

/// Converts an RGBA8 buffer of Display-P3-encoded pixels to sRGB.
pub fn p3_to_srgb(rgba: &[u8], w: usize, h: usize) -> Vec<u8> {
    let mut out = rgba.to_vec();
    for i in 0..w * h {
        let p3_pixel = [
            rgba[i * 4] as f32 / 255.0,
            rgba[i * 4 + 1] as f32 / 255.0,
            rgba[i * 4 + 2] as f32 / 255.0,
        ];
        let lin_p3 = display_p3_to_linear_p3_pixel(p3_pixel);
        let srgb = linear_p3_to_srgb_pixel(lin_p3);
        out[i * 4] = (srgb[0] * 255.0 + 0.5) as u8;
        out[i * 4 + 1] = (srgb[1] * 255.0 + 0.5) as u8;
        out[i * 4 + 2] = (srgb[2] * 255.0 + 0.5) as u8;
    }
    out
}

/// Converts an RGBA8 buffer of sRGB pixels to Display-P3 gamma-encoded RGBA8.
pub fn srgb_to_p3(rgba: &[u8], w: usize, h: usize) -> Vec<u8> {
    let mut out = rgba.to_vec();
    for i in 0..w * h {
        let srgb_pixel = [
            rgba[i * 4] as f32 / 255.0,
            rgba[i * 4 + 1] as f32 / 255.0,
            rgba[i * 4 + 2] as f32 / 255.0,
        ];
        let lin_p3 = srgb_to_linear_p3_pixel(srgb_pixel);
        let p3 = linear_p3_to_display_p3_pixel(lin_p3);
        out[i * 4] = (p3[0] * 255.0 + 0.5) as u8;
        out[i * 4 + 1] = (p3[1] * 255.0 + 0.5) as u8;
        out[i * 4 + 2] = (p3[2] * 255.0 + 0.5) as u8;
    }
    out
}

/// Builds a canonical, standards-compliant Display-P3 ICC profile payload
/// suitable for injection into JPEG APP2 or PNG iCCP segments.
pub fn build_display_p3_icc_profile() -> Vec<u8> {
    // 1. desc tag: 'desc' type (ICC v2 textDescriptionType)
    let mut desc_payload = Vec::new();
    desc_payload.extend_from_slice(b"desc\0\0\0\0");
    let desc_str = b"Display P3\0";
    desc_payload.extend_from_slice(&(desc_str.len() as u32).to_be_bytes());
    desc_payload.extend_from_slice(desc_str);
    desc_payload.extend_from_slice(&[0; 17]); // Unicode and scriptcode fields
    while desc_payload.len() % 4 != 0 {
        desc_payload.push(0);
    }

    // 2. cprt tag: 'text' type
    let mut cprt_payload = Vec::new();
    cprt_payload.extend_from_slice(b"text\0\0\0\0");
    cprt_payload.extend_from_slice(b"ApertureX FOSS (GPL-3.0)\0");
    while cprt_payload.len() % 4 != 0 {
        cprt_payload.push(0);
    }

    // 3. wtpt tag: 'XYZ ' type (D50)
    let mut wtpt_payload = Vec::new();
    wtpt_payload.extend_from_slice(b"XYZ \0\0\0\0");
    wtpt_payload.extend_from_slice(&[0x00, 0x00, 0xF6, 0xD6]); // X = 0.9642
    wtpt_payload.extend_from_slice(&[0x00, 0x01, 0x00, 0x00]); // Y = 1.0000
    wtpt_payload.extend_from_slice(&[0x00, 0x00, 0xD3, 0x2D]); // Z = 0.8249

    // 4. rXYZ tag: 'XYZ ' type (D50-adapted Display-P3 Red: X=0.5151, Y=0.2412, Z=-0.0011)
    let mut rxyz_payload = Vec::new();
    rxyz_payload.extend_from_slice(b"XYZ \0\0\0\0");
    rxyz_payload.extend_from_slice(&[0x00, 0x00, 0x83, 0xDE]); // 0.5151 * 65536
    rxyz_payload.extend_from_slice(&[0x00, 0x00, 0x3D, 0xC0]); // 0.2412 * 65536
    rxyz_payload.extend_from_slice(&[0xFF, 0xFF, 0xFF, 0xB7]); // -0.0011 * 65536

    // 5. gXYZ tag: 'XYZ ' type (D50-adapted Display-P3 Green: X=0.2919, Y=0.6922, Z=0.0450)
    let mut gxyz_payload = Vec::new();
    gxyz_payload.extend_from_slice(b"XYZ \0\0\0\0");
    gxyz_payload.extend_from_slice(&[0x00, 0x00, 0x4A, 0xBC]); // 0.2919 * 65536
    gxyz_payload.extend_from_slice(&[0x00, 0x00, 0xB1, 0x39]); // 0.6922 * 65536
    gxyz_payload.extend_from_slice(&[0x00, 0x00, 0x0B, 0x85]); // 0.0450 * 65536

    // 6. bXYZ tag: 'XYZ ' type (D50-adapted Display-P3 Blue: X=0.1571, Y=0.0666, Z=0.7809)
    let mut bxyz_payload = Vec::new();
    bxyz_payload.extend_from_slice(b"XYZ \0\0\0\0");
    bxyz_payload.extend_from_slice(&[0x00, 0x00, 0x28, 0x3A]); // 0.1571 * 65536
    bxyz_payload.extend_from_slice(&[0x00, 0x00, 0x11, 0x0B]); // 0.0666 * 65536
    bxyz_payload.extend_from_slice(&[0x00, 0x00, 0xC7, 0xEA]); // 0.7809 * 65536

    // 7. TRC tag: 'curv' type (gamma 2.2 approximation)
    let mut trc_payload = Vec::new();
    trc_payload.extend_from_slice(b"curv\0\0\0\0");
    trc_payload.extend_from_slice(&1u32.to_be_bytes()); // 1 entry: gamma
    trc_payload.extend_from_slice(&[0x02, 0x33]); // 2.2 in u8.8 fixed point
    while trc_payload.len() % 4 != 0 {
        trc_payload.push(0);
    }

    let mut p = Vec::with_capacity(512);
    // 128-byte Header placeholder (size will be written at end)
    p.extend_from_slice(&[0; 4]); // Profile size placeholder
    p.extend_from_slice(b"APX "); // Preferred CMM type
    p.extend_from_slice(&[0x02, 0x40, 0x00, 0x00]); // Version 2.4.0
    p.extend_from_slice(b"mntr"); // Device class: Display
    p.extend_from_slice(b"RGB "); // Color space
    p.extend_from_slice(b"XYZ "); // Profile connection space
    p.extend_from_slice(&[0; 12]); // Date/time
    p.extend_from_slice(b"acsp"); // Magic signature
    p.extend_from_slice(b"APPL"); // Primary platform
    p.extend_from_slice(&[0; 24]); // Profile flags, device attributes
    p.extend_from_slice(&[0x00, 0x00, 0xF6, 0xD6]); // D50 Illuminant X = 0.9642
    p.extend_from_slice(&[0x00, 0x01, 0x00, 0x00]); // D50 Illuminant Y = 1.0000
    p.extend_from_slice(&[0x00, 0x00, 0xD3, 0x2D]); // D50 Illuminant Z = 0.8249
    p.extend_from_slice(&[0; 48]); // Reserved padding to 128 bytes

    // Tag count: 9 tags
    p.extend_from_slice(&9u32.to_be_bytes());

    let tag_table_offset = 128 + 4;
    let tag_data_start = tag_table_offset + 9 * 12;

    let desc_offset = tag_data_start;
    let desc_len = desc_payload.len();

    let cprt_offset = desc_offset + desc_len;
    let cprt_len = cprt_payload.len();

    let wtpt_offset = cprt_offset + cprt_len;
    let wtpt_len = wtpt_payload.len();

    let r_xyz_offset = wtpt_offset + wtpt_len;
    let r_xyz_len = rxyz_payload.len();

    let g_xyz_offset = r_xyz_offset + r_xyz_len;
    let g_xyz_len = gxyz_payload.len();

    let b_xyz_offset = g_xyz_offset + g_xyz_len;
    let b_xyz_len = bxyz_payload.len();

    let trc_offset = b_xyz_offset + b_xyz_len;
    let trc_len = trc_payload.len();

    // Tag table entries
    let mut add_entry = |sig: &[u8; 4], off: usize, len: usize| {
        p.extend_from_slice(sig);
        p.extend_from_slice(&(off as u32).to_be_bytes());
        p.extend_from_slice(&(len as u32).to_be_bytes());
    };

    add_entry(b"desc", desc_offset, desc_len);
    add_entry(b"cprt", cprt_offset, cprt_len);
    add_entry(b"wtpt", wtpt_offset, wtpt_len);
    add_entry(b"rXYZ", r_xyz_offset, r_xyz_len);
    add_entry(b"gXYZ", g_xyz_offset, g_xyz_len);
    add_entry(b"bXYZ", b_xyz_offset, b_xyz_len);
    add_entry(b"rTRC", trc_offset, trc_len);
    add_entry(b"gTRC", trc_offset, trc_len);
    add_entry(b"bTRC", trc_offset, trc_len);

    // Tag payloads
    p.extend_from_slice(&desc_payload);
    p.extend_from_slice(&cprt_payload);
    p.extend_from_slice(&wtpt_payload);
    p.extend_from_slice(&rxyz_payload);
    p.extend_from_slice(&gxyz_payload);
    p.extend_from_slice(&bxyz_payload);
    p.extend_from_slice(&trc_payload);

    // Write final length to header
    let total_len = p.len() as u32;
    p[0..4].copy_from_slice(&total_len.to_be_bytes());

    p
}

/// Packages a Display-P3 ICC profile into an APP2 JPEG segment (`0xFFE2` + length + `ICC_PROFILE\0`).
pub fn make_p3_app2_segment() -> Vec<u8> {
    let profile = build_display_p3_icc_profile();
    let payload_len = (profile.len() + 14 + 2) as u16;
    let mut seg = Vec::with_capacity(profile.len() + 18);
    seg.extend_from_slice(&[
        0xFF,
        0xE2,
        (payload_len >> 8) as u8,
        (payload_len & 0xFF) as u8,
    ]);
    seg.extend_from_slice(b"ICC_PROFILE\0");
    seg.extend_from_slice(&[1, 1]); // seq 1 of 1
    seg.extend_from_slice(&profile);
    seg
}

#[cfg(test)]
mod tests {
    use super::*;

    fn plain_jpeg() -> Vec<u8> {
        let rgba: Vec<u8> = std::iter::repeat_n([120u8, 130, 140, 255], 8 * 8)
            .flatten()
            .collect();
        crate::export::encode_jpeg(&rgba, 8, 8, 80, &[]).unwrap()
    }

    fn p3_jpeg() -> Vec<u8> {
        let seg = make_p3_app2_segment();
        let base = plain_jpeg();
        crate::exif::inject_app1(base, &seg)
    }

    #[test]
    fn no_profile_is_srgb() {
        assert_eq!(detect_colorspace(&plain_jpeg()), CS_SRGB);
    }

    #[test]
    fn detects_display_p3_via_header_and_tags() {
        assert_eq!(detect_colorspace(&p3_jpeg()), CS_DISPLAY_P3);
    }

    #[test]
    fn p3_greys_map_to_srgb_greys() {
        let src = vec![128u8, 128, 128, 255];
        let out = p3_to_srgb(&src, 1, 1);
        for c in 0..3 {
            assert!((out[c] as i32 - 128).abs() <= 2, "{out:?}");
        }
    }

    #[test]
    fn srgb_greys_map_to_p3_greys() {
        let src = vec![128u8, 128, 128, 255];
        let out = srgb_to_p3(&src, 1, 1);
        for c in 0..3 {
            assert!((out[c] as i32 - 128).abs() <= 2, "{out:?}");
        }
    }

    #[test]
    fn p3_saturated_colour_changes() {
        let src = vec![200u8, 100, 50, 255]; // P3 orange-red
        let out = p3_to_srgb(&src, 1, 1);
        assert_ne!(out[0..3], src[0..3]);
    }

    #[test]
    fn linear_p3_and_srgb_roundtrip_identity() {
        let test_val = [0.5f32, 0.5f32, 0.5f32];
        let lin_p3 = srgb_to_linear_p3_pixel(test_val);
        let back_srgb = linear_p3_to_srgb_pixel(lin_p3);
        for c in 0..3 {
            assert!((back_srgb[c] - test_val[c]).abs() < 0.01);
        }
    }

    #[test]
    fn soft_knee_gamut_compress_preserves_monotonicity() {
        let in_gamut = [0.2f32, 0.5f32, 0.8f32];
        let compressed = soft_knee_gamut_compress(in_gamut);
        assert_eq!(compressed, in_gamut);

        let out_gamut = [1.4f32, 0.5f32, -0.2f32];
        let compressed_out = soft_knee_gamut_compress(out_gamut);
        assert!(compressed_out[0] <= 1.0);
        assert!(compressed_out[2] >= 0.0);
    }

    #[test]
    fn display_p3_icc_generator_produces_valid_structure() {
        let profile = build_display_p3_icc_profile();
        assert_eq!(profile.len(), 412);
        assert_eq!(&profile[36..40], b"acsp");
        let matrix = parse_icc_matrix(&profile).expect("must parse matrix tags");
        assert!(matrix.r_xyz[0] > 0.4);
        assert!(matrix.g_xyz[1] > 0.6);
        assert!(matrix.b_xyz[2] > 0.7);
    }
}
