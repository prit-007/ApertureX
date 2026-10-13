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
}
