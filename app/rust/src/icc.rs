//! Wide-gamut input handling (partial #15): detect a Display-P3 ICC profile in
//! a JPEG and convert P3 pixels to sRGB so imported photos don't look "dull"
//! (or over-saturated) in an sRGB pipeline. Full f16/linear-P3 working space is
//! a larger architectural change tracked on the issue.

use crate::color::{linear_to_srgb, srgb_to_linear};

pub const CS_UNKNOWN: u32 = 0;
pub const CS_SRGB: u32 = 1;
pub const CS_DISPLAY_P3: u32 = 2;

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

/// Detects the embedded colour space of [jpeg].
pub fn detect_colorspace(jpeg: &[u8]) -> u32 {
    match extract_icc(jpeg) {
        None => CS_SRGB, // no profile → assume sRGB
        Some(profile) => {
            if contains(&profile, b"Display P3") || contains(&profile, b"P3") {
                CS_DISPLAY_P3
            } else {
                CS_SRGB
            }
        }
    }
}

fn contains(haystack: &[u8], needle: &[u8]) -> bool {
    haystack.windows(needle.len()).any(|w| w == needle)
}

/// Linear Display-P3 → linear sRGB (both D65).
const P3_TO_SRGB: [[f32; 3]; 3] = [
    [1.224_940_1, -0.224_940_4, 0.0],
    [-0.042_056_9, 1.042_057_1, 0.0],
    [-0.019_637_6, -0.078_636_1, 1.098_273_6],
];

/// Converts an RGBA8 buffer of Display-P3-encoded pixels to sRGB.
pub fn p3_to_srgb(rgba: &[u8], w: usize, h: usize) -> Vec<u8> {
    let mut out = rgba.to_vec();
    for i in 0..w * h {
        let lin = [
            srgb_to_linear(rgba[i * 4] as f32 / 255.0),
            srgb_to_linear(rgba[i * 4 + 1] as f32 / 255.0),
            srgb_to_linear(rgba[i * 4 + 2] as f32 / 255.0),
        ];
        for c in 0..3 {
            let v =
                P3_TO_SRGB[c][0] * lin[0] + P3_TO_SRGB[c][1] * lin[1] + P3_TO_SRGB[c][2] * lin[2];
            out[i * 4 + c] = (linear_to_srgb(v.max(0.0)) * 255.0 + 0.5).clamp(0.0, 255.0) as u8;
        }
    }
    out
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
        let mut profile = vec![0u8; 20];
        profile.extend_from_slice(b"...Display P3 description...");
        let payload_len = (profile.len() + 14 + 2) as u16;
        let mut seg = vec![
            0xFF,
            0xE2,
            (payload_len >> 8) as u8,
            (payload_len & 0xFF) as u8,
        ];
        seg.extend_from_slice(b"ICC_PROFILE\0");
        seg.extend_from_slice(&[1, 1]); // seq, count
        seg.extend_from_slice(&profile);
        let base = plain_jpeg();
        crate::exif::inject_app1(base, &seg)
    }

    #[test]
    fn no_profile_is_srgb() {
        assert_eq!(detect_colorspace(&plain_jpeg()), CS_SRGB);
    }

    #[test]
    fn detects_display_p3() {
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
    fn p3_saturated_colour_changes() {
        let src = vec![200u8, 100, 50, 255]; // P3 orange-red
        let out = p3_to_srgb(&src, 1, 1);
        assert_ne!(out[0..3], src[0..3]);
    }
}
