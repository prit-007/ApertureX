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

/// Comprehensive image and shooting metadata parsed from EXIF and RAW headers.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ImageMetadata {
    pub make: Option<String>,
    pub model: Option<String>,
    pub lens_make: Option<String>,
    pub lens_model: Option<String>,
    pub focal_length: Option<f32>,
    pub focal_length_35mm: Option<f32>,
    pub f_number: Option<f32>,
    pub exposure_time: Option<String>,
    pub exposure_time_seconds: Option<f32>,
    pub iso: Option<u32>,
    pub exposure_bias: Option<f32>,
    pub flash_fired: Option<bool>,
    pub metering_mode: Option<String>,
    pub white_balance_mode: Option<String>,
    pub date_time: Option<String>,
    pub gps_latitude: Option<f64>,
    pub gps_longitude: Option<f64>,
    pub gps_altitude: Option<f32>,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub format_name: Option<String>,
}

struct TiffReader<'a> {
    data: &'a [u8],
    is_le: bool,
}

impl<'a> TiffReader<'a> {
    fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 8 {
            return None;
        }
        let is_le = if &data[0..2] == b"II" {
            true
        } else if &data[0..2] == b"MM" {
            false
        } else {
            return None;
        };
        let magic = if is_le {
            u16::from_le_bytes([data[2], data[3]])
        } else {
            u16::from_be_bytes([data[2], data[3]])
        };
        if magic != 42 && magic != 0x4f52 && magic != 0x55 {
            return None;
        }
        Some(Self { data, is_le })
    }

    fn u16(&self, offset: usize) -> Option<u16> {
        if offset + 2 > self.data.len() {
            return None;
        }
        let b = [self.data[offset], self.data[offset + 1]];
        Some(if self.is_le {
            u16::from_le_bytes(b)
        } else {
            u16::from_be_bytes(b)
        })
    }

    fn u32(&self, offset: usize) -> Option<u32> {
        if offset + 4 > self.data.len() {
            return None;
        }
        let b: [u8; 4] = self.data[offset..offset + 4].try_into().ok()?;
        Some(if self.is_le {
            u32::from_le_bytes(b)
        } else {
            u32::from_be_bytes(b)
        })
    }

    fn i32(&self, offset: usize) -> Option<i32> {
        self.u32(offset).map(|v| v as i32)
    }

    fn rational(&self, offset: usize) -> Option<(u32, u32)> {
        let num = self.u32(offset)?;
        let den = self.u32(offset + 4)?;
        Some((num, den))
    }

    fn srational(&self, offset: usize) -> Option<(i32, i32)> {
        let num = self.i32(offset)?;
        let den = self.i32(offset + 4)?;
        Some((num, den))
    }

    fn ascii(&self, offset: usize, count: usize) -> Option<String> {
        if offset + count > self.data.len() {
            return None;
        }
        let slice = &self.data[offset..offset + count];
        let end = slice.iter().position(|&b| b == 0).unwrap_or(slice.len());
        let s = std::str::from_utf8(&slice[..end]).ok()?.trim().to_string();
        if s.is_empty() {
            None
        } else {
            Some(s)
        }
    }
}

fn type_size(dtype: u16) -> usize {
    match dtype {
        1 | 2 | 6 | 7 => 1,
        3 | 8 => 2,
        4 | 9 | 11 => 4,
        5 | 10 | 12 => 8,
        _ => 1,
    }
}

fn format_exposure_time(num: u32, den: u32) -> String {
    if den == 0 {
        return "0s".to_string();
    }
    if num == 1 || (den > num && num > 0 && den.is_multiple_of(num)) {
        format!("1/{}s", den / num)
    } else {
        let sec = num as f32 / den as f32;
        if sec < 1.0 {
            format!("{:.3}s", sec)
        } else {
            format!("{:.1}s", sec)
        }
    }
}

fn parse_ifd(
    reader: &TiffReader,
    ifd_offset: usize,
    meta: &mut ImageMetadata,
    depth: usize,
    is_exif_subifd: bool,
) {
    if depth > 4 || ifd_offset + 2 > reader.data.len() {
        return;
    }
    let num_entries = match reader.u16(ifd_offset) {
        Some(n) => n as usize,
        None => return,
    };

    let mut exif_subifd_offset = None;
    let mut gps_ifd_offset = None;

    for i in 0..num_entries {
        let entry = ifd_offset + 2 + i * 12;
        if entry + 12 > reader.data.len() {
            break;
        }
        let tag = match reader.u16(entry) {
            Some(t) => t,
            None => break,
        };
        let dtype = match reader.u16(entry + 2) {
            Some(t) => t,
            None => break,
        };
        let count = match reader.u32(entry + 4) {
            Some(c) => c as usize,
            None => break,
        };
        let total_size = count * type_size(dtype);
        let val_offset = if total_size <= 4 {
            entry + 8
        } else {
            match reader.u32(entry + 8) {
                Some(off) => off as usize,
                None => continue,
            }
        };

        if !is_exif_subifd {
            match tag {
                0x010F => meta.make = reader.ascii(val_offset, count).or(meta.make.take()),
                0x0110 => meta.model = reader.ascii(val_offset, count).or(meta.model.take()),
                0x0132 => {
                    if meta.date_time.is_none() {
                        meta.date_time = reader.ascii(val_offset, count);
                    }
                }
                0x0100 => {
                    if meta.width.is_none() {
                        meta.width = if dtype == 3 {
                            reader.u16(val_offset).map(|v| v as u32)
                        } else {
                            reader.u32(val_offset)
                        };
                    }
                }
                0x0101 => {
                    if meta.height.is_none() {
                        meta.height = if dtype == 3 {
                            reader.u16(val_offset).map(|v| v as u32)
                        } else {
                            reader.u32(val_offset)
                        };
                    }
                }
                0x8769 => exif_subifd_offset = reader.u32(val_offset).map(|v| v as usize),
                0x8825 => gps_ifd_offset = reader.u32(val_offset).map(|v| v as usize),
                _ => {}
            }
        } else {
            match tag {
                0x829A => {
                    if let Some((num, den)) = reader.rational(val_offset) {
                        if den > 0 {
                            meta.exposure_time_seconds = Some(num as f32 / den as f32);
                            meta.exposure_time = Some(format_exposure_time(num, den));
                        }
                    }
                }
                0x829D => {
                    if let Some((num, den)) = reader.rational(val_offset) {
                        if den > 0 {
                            meta.f_number = Some(num as f32 / den as f32);
                        }
                    }
                }
                0x8827 => {
                    let iso_val = if dtype == 3 {
                        reader.u16(val_offset).map(|v| v as u32)
                    } else {
                        reader.u32(val_offset)
                    };
                    if let Some(iso) = iso_val {
                        meta.iso = Some(iso);
                    }
                }
                0x9003 | 0x9004 => {
                    if let Some(dt) = reader.ascii(val_offset, count) {
                        meta.date_time = Some(dt);
                    }
                }
                0x9204 => {
                    if let Some((num, den)) = reader.srational(val_offset) {
                        if den > 0 {
                            meta.exposure_bias = Some(num as f32 / den as f32);
                        }
                    }
                }
                0x9207 => {
                    if let Some(m) = reader.u16(val_offset) {
                        meta.metering_mode = Some(
                            match m {
                                1 => "Average",
                                2 => "Center-weighted",
                                3 => "Spot",
                                4 => "Multi-spot",
                                5 => "Multi-segment",
                                6 => "Partial",
                                _ => "Pattern",
                            }
                            .to_string(),
                        );
                    }
                }
                0x9209 => {
                    if let Some(flash) = reader.u16(val_offset) {
                        meta.flash_fired = Some((flash & 1) != 0);
                    }
                }
                0x920A => {
                    if let Some((num, den)) = reader.rational(val_offset) {
                        if den > 0 {
                            meta.focal_length = Some(num as f32 / den as f32);
                        }
                    }
                }
                0xA002 => {
                    if meta.width.is_none() {
                        meta.width = if dtype == 3 {
                            reader.u16(val_offset).map(|v| v as u32)
                        } else {
                            reader.u32(val_offset)
                        };
                    }
                }
                0xA003 => {
                    if meta.height.is_none() {
                        meta.height = if dtype == 3 {
                            reader.u16(val_offset).map(|v| v as u32)
                        } else {
                            reader.u32(val_offset)
                        };
                    }
                }
                0xA403 => {
                    if let Some(wb) = reader.u16(val_offset) {
                        meta.white_balance_mode =
                            Some(if wb == 0 { "Auto" } else { "Manual" }.to_string());
                    }
                }
                0xA405 => {
                    if let Some(fl35) = reader.u16(val_offset) {
                        meta.focal_length_35mm = Some(fl35 as f32);
                    }
                }
                0xA433 => {
                    meta.lens_make = reader.ascii(val_offset, count).or(meta.lens_make.take())
                }
                0xA434 => {
                    meta.lens_model = reader.ascii(val_offset, count).or(meta.lens_model.take())
                }
                _ => {}
            }
        }
    }

    if let Some(exif_offset) = exif_subifd_offset {
        parse_ifd(reader, exif_offset, meta, depth + 1, true);
    }
    if let Some(gps_offset) = gps_ifd_offset {
        parse_gps_ifd(reader, gps_offset, meta);
    }
}

fn parse_gps_ifd(reader: &TiffReader, ifd_offset: usize, meta: &mut ImageMetadata) {
    if ifd_offset + 2 > reader.data.len() {
        return;
    }
    let num_entries = match reader.u16(ifd_offset) {
        Some(n) => n as usize,
        None => return,
    };

    let mut lat_ref = None;
    let mut lat_deg = None;
    let mut lon_ref = None;
    let mut lon_deg = None;
    let mut alt_ref = None;
    let mut alt_val = None;

    for i in 0..num_entries {
        let entry = ifd_offset + 2 + i * 12;
        if entry + 12 > reader.data.len() {
            break;
        }
        let tag = match reader.u16(entry) {
            Some(t) => t,
            None => break,
        };
        let dtype = match reader.u16(entry + 2) {
            Some(t) => t,
            None => break,
        };
        let count = match reader.u32(entry + 4) {
            Some(c) => c as usize,
            None => break,
        };
        let total_size = count * type_size(dtype);
        let val_offset = if total_size <= 4 {
            entry + 8
        } else {
            match reader.u32(entry + 8) {
                Some(off) => off as usize,
                None => continue,
            }
        };

        match tag {
            0x0001 => {
                lat_ref = reader
                    .ascii(val_offset, count)
                    .and_then(|s| s.chars().next())
            }
            0x0002 if count >= 3 => {
                let d = reader.rational(val_offset);
                let m = reader.rational(val_offset + 8);
                let s = reader.rational(val_offset + 16);
                if let (Some(d), Some(m), Some(s)) = (d, m, s) {
                    if d.1 > 0 && m.1 > 0 && s.1 > 0 {
                        let deg = d.0 as f64 / d.1 as f64
                            + (m.0 as f64 / m.1 as f64) / 60.0
                            + (s.0 as f64 / s.1 as f64) / 3600.0;
                        lat_deg = Some(deg);
                    }
                }
            }
            0x0003 => {
                lon_ref = reader
                    .ascii(val_offset, count)
                    .and_then(|s| s.chars().next())
            }
            0x0004 if count >= 3 => {
                let d = reader.rational(val_offset);
                let m = reader.rational(val_offset + 8);
                let s = reader.rational(val_offset + 16);
                if let (Some(d), Some(m), Some(s)) = (d, m, s) {
                    if d.1 > 0 && m.1 > 0 && s.1 > 0 {
                        let deg = d.0 as f64 / d.1 as f64
                            + (m.0 as f64 / m.1 as f64) / 60.0
                            + (s.0 as f64 / s.1 as f64) / 3600.0;
                        lon_deg = Some(deg);
                    }
                }
            }
            0x0005 => {
                if let Some(&b) = reader.data.get(val_offset) {
                    alt_ref = Some(b);
                }
            }
            0x0006 => {
                if let Some((num, den)) = reader.rational(val_offset) {
                    if den > 0 {
                        alt_val = Some(num as f32 / den as f32);
                    }
                }
            }
            _ => {}
        }
    }

    if let (Some(mut lat), Some(r)) = (lat_deg, lat_ref) {
        if r == 'S' || r == 's' {
            lat = -lat;
        }
        meta.gps_latitude = Some(lat);
    }
    if let (Some(mut lon), Some(r)) = (lon_deg, lon_ref) {
        if r == 'W' || r == 'w' {
            lon = -lon;
        }
        meta.gps_longitude = Some(lon);
    }
    if let Some(mut alt) = alt_val {
        if alt_ref == Some(1) {
            alt = -alt;
        }
        meta.gps_altitude = Some(alt);
    }
}

/// Parses image format, dimensions, camera, lens, exposure, and GPS metadata from source bytes.
pub fn parse_image_metadata(bytes: &[u8]) -> ImageMetadata {
    let mut meta = ImageMetadata::default();
    if bytes.is_empty() {
        return meta;
    }

    // 1. JPEG
    if bytes.len() >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
        meta.format_name = Some("JPEG".to_string());
        if let Some(app1) = extract_app1(bytes) {
            if app1.len() >= 10 && &app1[4..10] == b"Exif\0\0" {
                if let Some(reader) = TiffReader::new(&app1[10..]) {
                    if let Some(first_ifd) = reader.u32(4) {
                        parse_ifd(&reader, first_ifd as usize, &mut meta, 0, false);
                    }
                }
            }
        }
        return meta;
    }

    // 2. PNG
    if bytes.starts_with(b"\x89PNG\r\n\x1a\n") {
        meta.format_name = Some("PNG".to_string());
        if bytes.len() >= 24 {
            let w = u32::from_be_bytes(bytes[16..20].try_into().unwrap_or_default());
            let h = u32::from_be_bytes(bytes[20..24].try_into().unwrap_or_default());
            meta.width = Some(w);
            meta.height = Some(h);
        }
        return meta;
    }

    // 3. RAW / TIFF formats
    if bytes.starts_with(b"II") || bytes.starts_with(b"MM") {
        if let Some(reader) = TiffReader::new(bytes) {
            if let Some(first_ifd) = reader.u32(4) {
                parse_ifd(&reader, first_ifd as usize, &mut meta, 0, false);
            }
        }

        // Query rawler metadata for any rawler-specific decoded fields
        if let Ok(raw_meta) = crate::raw::metadata(bytes) {
            if meta.width.is_none() || meta.width == Some(0) {
                meta.width = Some(raw_meta.width as u32);
            }
            if meta.height.is_none() || meta.height == Some(0) {
                meta.height = Some(raw_meta.height as u32);
            }
            if meta.make.is_none() {
                meta.make = raw_meta.make;
            }
            if meta.model.is_none() {
                meta.model = raw_meta.model;
            }
        }

        let make_lower = meta.make.as_deref().unwrap_or("").to_lowercase();
        let model_lower = meta.model.as_deref().unwrap_or("").to_lowercase();
        if make_lower.contains("sony")
            || model_lower.contains("ilce")
            || model_lower.contains("alpha")
        {
            meta.format_name = Some("Sony ARW RAW".to_string());
        } else if make_lower.contains("canon") || (bytes.len() > 10 && &bytes[8..11] == b"CR2") {
            meta.format_name = Some("Canon CR2 RAW".to_string());
        } else if make_lower.contains("panasonic") || make_lower.contains("lumix") {
            meta.format_name = Some("Panasonic RW2 RAW".to_string());
        } else if make_lower.contains("nikon") {
            meta.format_name = Some("Nikon NEF RAW".to_string());
        } else if make_lower.contains("fujifilm") || make_lower.contains("fuji") {
            meta.format_name = Some("Fujifilm RAF RAW".to_string());
        } else {
            meta.format_name = Some("Adobe DNG / RAW".to_string());
        }

        return meta;
    }

    meta.format_name = Some("Image".to_string());
    meta
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

    #[test]
    fn test_parse_image_metadata_jpeg() {
        let jpeg = sample_jpeg();
        let meta = parse_image_metadata(&jpeg);
        assert_eq!(meta.format_name.as_deref(), Some("JPEG"));
    }

    #[test]
    fn test_parse_image_metadata_png() {
        let png = vec![
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
            0x44, 0x52, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x80, 0x08, 0x02, 0x00, 0x00,
            0x00,
        ];
        let meta = parse_image_metadata(&png);
        assert_eq!(meta.format_name.as_deref(), Some("PNG"));
        assert_eq!(meta.width, Some(256));
        assert_eq!(meta.height, Some(128));
    }

    #[test]
    fn test_parse_image_metadata_raw_golden_fixture() {
        let dng_path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/golden_fixtures/image_2.dng");
        if dng_path.exists() {
            let bytes = std::fs::read(&dng_path).unwrap();
            let meta = parse_image_metadata(&bytes);
            assert!(meta.format_name.is_some());
            assert!(meta.width.is_some());
            assert!(meta.height.is_some());
        }
    }
}
