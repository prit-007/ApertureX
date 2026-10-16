//! EXIF preservation. Mobile FOSS editors often destroy EXIF (GPS, DateTaken,
//! ISO, camera) on export, which gets photos resorted as "new". We carry the
//! source JPEG's APP1 (Exif) segment over to the exported file verbatim.

/// Returns the APP1/Exif segment of [jpeg] (including the `FF E1` marker and
/// length), or `None` if there is none. Only the first Exif APP1 is returned.
pub fn extract_app1(jpeg: &[u8]) -> Option<Vec<u8>> {
    if jpeg.len() < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8 {
        return None; // not a JPEG (no SOI)
    }
    let mut i = 2usize;
    while i + 4 <= jpeg.len() {
        if jpeg[i] != 0xFF {
            break;
        }
        let marker = jpeg[i + 1];
        // Markers without a payload.
        if marker == 0xD8 || marker == 0x01 || (0xD0..=0xD9).contains(&marker) {
            i += 2;
            continue;
        }
        let len = ((jpeg[i + 2] as usize) << 8) | jpeg[i + 3] as usize;
        let seg_end = i + 2 + len;
        if seg_end > jpeg.len() || len < 2 {
            break;
        }
        if marker == 0xE1 {
            let payload = &jpeg[i + 4..seg_end];
            if payload.len() >= 6 && &payload[..6] == b"Exif\0\0" {
                return Some(jpeg[i..seg_end].to_vec());
            }
        }
        if marker == 0xDA {
            break; // start of scan; metadata precedes it
        }
        i = seg_end;
    }
    None
}

/// Inserts [app1] (a full `FF E1` segment) immediately after the SOI of [jpeg].
/// An empty [app1] returns [jpeg] unchanged.
pub fn inject_app1(jpeg: Vec<u8>, app1: &[u8]) -> Vec<u8> {
    if app1.is_empty() || jpeg.len() < 2 || jpeg[0] != 0xFF || jpeg[1] != 0xD8 {
        return jpeg;
    }
    let mut out = Vec::with_capacity(jpeg.len() + app1.len());
    out.extend_from_slice(&jpeg[..2]); // SOI
    out.extend_from_slice(app1); // APP1 (marker + length + payload)
    out.extend_from_slice(&jpeg[2..]);
    out
}

/// Decodes standard RFC 4648 base64 data, ignoring whitespace and newlines.
pub fn base64_decode(input: &[u8]) -> Option<Vec<u8>> {
    let mut out = Vec::with_capacity(input.len() * 3 / 4);
    let mut buf = 0u32;
    let mut bits = 0;
    for &b in input {
        let val = match b {
            b'A'..=b'Z' => b - b'A',
            b'a'..=b'z' => b - b'a' + 26,
            b'0'..=b'9' => b - b'0' + 52,
            b'+' => 62,
            b'/' => 63,
            b'=' | b' ' | b'\n' | b'\r' | b'\t' => continue,
            _ => return None,
        };
        buf = (buf << 6) | (val as u32);
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((buf >> bits) as u8);
            buf &= (1 << bits) - 1;
        }
    }
    Some(out)
}

/// Extracts all XMP metadata packets from APP1 segments in [jpeg].
pub fn extract_xmp(jpeg: &[u8]) -> Vec<Vec<u8>> {
    if jpeg.len() < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8 {
        return Vec::new();
    }
    let mut xmp_packets = Vec::new();
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
        if marker == 0xE1 {
            let payload = &jpeg[i + 4..seg_end];
            const XMP_HDR: &[u8] = b"http://ns.adobe.com/xap/1.0/\0";
            const XMP_EXT_HDR: &[u8] = b"http://ns.adobe.com/xmp/extension/\0";
            if payload.starts_with(XMP_HDR) {
                xmp_packets.push(payload[XMP_HDR.len()..].to_vec());
            } else if payload.starts_with(XMP_EXT_HDR) {
                xmp_packets.push(payload[XMP_EXT_HDR.len()..].to_vec());
            } else if payload
                .windows(8)
                .any(|w| w == b"GDepth:\0" || w == b"<x:xmpme")
            {
                xmp_packets.push(payload.to_vec());
            }
        }
        if marker == 0xDA {
            break;
        }
        i = seg_end;
    }
    xmp_packets
}

/// Attempts to extract an embedded depth map from JPEG container metadata
/// (Google GDepth XMP namespace or MPF secondary streams).
/// Returns `Some((depth_grayscale_pixels, width, height))` on success, or `None`.
pub fn extract_embedded_depth(jpeg: &[u8]) -> Option<(Vec<u8>, usize, usize)> {
    let xmp_list = extract_xmp(jpeg);
    for xmp in xmp_list {
        // Look for GDepth:Data attribute or tag
        const TARGET_ATTR: &[u8] = b"GDepth:Data=\"";
        const TARGET_ATTR_SINGLE: &[u8] = b"GDepth:Data='";
        const TARGET_TAG: &[u8] = b"<GDepth:Data>";

        let (data_start, quote_char) = if let Some(pos) = xmp
            .windows(TARGET_ATTR.len())
            .position(|w| w == TARGET_ATTR)
        {
            (pos + TARGET_ATTR.len(), b'"')
        } else if let Some(pos) = xmp
            .windows(TARGET_ATTR_SINGLE.len())
            .position(|w| w == TARGET_ATTR_SINGLE)
        {
            (pos + TARGET_ATTR_SINGLE.len(), b'\'')
        } else if let Some(pos) = xmp.windows(TARGET_TAG.len()).position(|w| w == TARGET_TAG) {
            (pos + TARGET_TAG.len(), b'<')
        } else {
            continue;
        };

        let data_end = if quote_char == b'<' {
            xmp[data_start..]
                .windows(2)
                .position(|w| w == b"</")
                .map(|p| data_start + p)
        } else {
            xmp[data_start..]
                .iter()
                .position(|&b| b == quote_char)
                .map(|p| data_start + p)
        };

        if let Some(end) = data_end {
            let b64 = &xmp[data_start..end];
            if let Some(decoded) = base64_decode(b64) {
                // If it's an embedded JPEG
                if decoded.len() >= 2 && decoded[0] == 0xFF && decoded[1] == 0xD8 {
                    if let Ok(img) = crate::decode::decode_rgba(&decoded) {
                        let mut gray = Vec::with_capacity(img.width * img.height);
                        for px in img.rgba.as_chunks::<4>().0 {
                            let luma = (0.2126 * px[0] as f32
                                + 0.7152 * px[1] as f32
                                + 0.0722 * px[2] as f32)
                                .round() as u8;
                            gray.push(luma);
                        }
                        return Some((gray, img.width, img.height));
                    }
                }
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A tiny real JPEG via our own encoder.
    fn sample_jpeg() -> Vec<u8> {
        let rgba: Vec<u8> = std::iter::repeat_n([120u8, 130, 140, 255], 8 * 8)
            .flatten()
            .collect();
        crate::export::encode_jpeg(&rgba, 8, 8, 80, &[]).unwrap()
    }

    /// A fake but structurally valid APP1/Exif segment.
    fn fake_exif() -> Vec<u8> {
        let payload = b"Exif\0\0FAKE-EXIF-DATA";
        let len = (payload.len() + 2) as u16;
        let mut seg = vec![0xFF, 0xE1, (len >> 8) as u8, (len & 0xFF) as u8];
        seg.extend_from_slice(payload);
        seg
    }

    #[test]
    fn no_exif_yields_none() {
        assert!(extract_app1(&sample_jpeg()).is_none());
    }

    #[test]
    fn inject_then_extract_round_trips() {
        let exif = fake_exif();
        let with = inject_app1(sample_jpeg(), &exif);
        assert_eq!(extract_app1(&with).unwrap(), exif);
    }

    #[test]
    fn injection_keeps_the_jpeg_decodable() {
        let with = inject_app1(sample_jpeg(), &fake_exif());
        assert_eq!(crate::decode::dimensions(&with).unwrap(), (8, 8));
    }

    #[test]
    fn empty_exif_is_a_no_op() {
        let jpeg = sample_jpeg();
        assert_eq!(inject_app1(jpeg.clone(), &[]), jpeg);
    }

    #[test]
    fn base64_roundtrip_test() {
        let data = b"Hello, ApertureX Embedded Depth World!";
        // Hand encode
        const TABLE: &[u8; 64] =
            b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let mut encoded = String::new();
        for chunk in data.chunks(3) {
            let b0 = chunk[0] as u32;
            let b1 = if chunk.len() > 1 { chunk[1] as u32 } else { 0 };
            let b2 = if chunk.len() > 2 { chunk[2] as u32 } else { 0 };
            let triple = (b0 << 16) | (b1 << 8) | b2;
            encoded.push(TABLE[((triple >> 18) & 0x3F) as usize] as char);
            encoded.push(TABLE[((triple >> 12) & 0x3F) as usize] as char);
            if chunk.len() > 1 {
                encoded.push(TABLE[((triple >> 6) & 0x3F) as usize] as char);
            } else {
                encoded.push('=');
            }
            if chunk.len() > 2 {
                encoded.push(TABLE[(triple & 0x3F) as usize] as char);
            } else {
                encoded.push('=');
            }
        }
        let decoded = base64_decode(encoded.as_bytes()).unwrap();
        assert_eq!(decoded, data);
    }

    #[test]
    fn no_embedded_depth_returns_none() {
        let jpeg = sample_jpeg();
        assert!(extract_embedded_depth(&jpeg).is_none());
    }

    #[test]
    fn embedded_gdepth_extraction_succeeds() {
        // Create an 8x8 depth JPEG
        let depth_rgba: Vec<u8> = std::iter::repeat_n([180u8, 180, 180, 255], 8 * 8)
            .flatten()
            .collect();
        let depth_jpeg = crate::export::encode_jpeg(&depth_rgba, 8, 8, 80, &[]).unwrap();

        // Base64 encode depth_jpeg
        const TABLE: &[u8; 64] =
            b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let mut b64_depth = String::new();
        for chunk in depth_jpeg.chunks(3) {
            let b0 = chunk[0] as u32;
            let b1 = if chunk.len() > 1 { chunk[1] as u32 } else { 0 };
            let b2 = if chunk.len() > 2 { chunk[2] as u32 } else { 0 };
            let triple = (b0 << 16) | (b1 << 8) | b2;
            b64_depth.push(TABLE[((triple >> 18) & 0x3F) as usize] as char);
            b64_depth.push(TABLE[((triple >> 12) & 0x3F) as usize] as char);
            if chunk.len() > 1 {
                b64_depth.push(TABLE[((triple >> 6) & 0x3F) as usize] as char);
            } else {
                b64_depth.push('=');
            }
            if chunk.len() > 2 {
                b64_depth.push(TABLE[(triple & 0x3F) as usize] as char);
            } else {
                b64_depth.push('=');
            }
        }

        // Build XMP payload with GDepth:Data
        let xmp_xml = format!(
            "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"><rdf:Description xmlns:GDepth=\"http://ns.google.com/photos/1.0/depthmap/\" GDepth:Format=\"RangeInverse\" GDepth:Near=\"0.1\" GDepth:Far=\"4.0\" GDepth:Mime=\"image/jpeg\" GDepth:Data=\"{}\"/></rdf:RDF></x:xmpmeta>",
            b64_depth
        );

        let mut app1_payload = Vec::new();
        app1_payload.extend_from_slice(b"http://ns.adobe.com/xap/1.0/\0");
        app1_payload.extend_from_slice(xmp_xml.as_bytes());

        let len = (app1_payload.len() + 2) as u16;
        let mut seg = vec![0xFF, 0xE1, (len >> 8) as u8, (len & 0xFF) as u8];
        seg.extend_from_slice(&app1_payload);

        let main_jpeg = sample_jpeg();
        let jpeg_with_depth = inject_app1(main_jpeg, &seg);

        let extracted = extract_embedded_depth(&jpeg_with_depth);
        assert!(extracted.is_some(), "Expected embedded depth to be found");
        let (depth_pixels, w, h) = extracted.unwrap();
        assert_eq!(w, 8);
        assert_eq!(h, 8);
        assert_eq!(depth_pixels.len(), 64);
        // Intensity is approx 180 (within lossy JPEG margin)
        assert!((depth_pixels[0] as i16 - 180).abs() <= 5);
    }
}
