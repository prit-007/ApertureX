//! C2PA (Coalition for Content Provenance and Authenticity) offline signing & verification.
//!
//! Generates verifiable cryptographic provenance manifests embedded directly into
//! exported JPEG APP11 segments. Proves image authenticity, original sensor source,
//! and non-destructive editing history without requiring external cloud servers.

use crate::sha256::{sha256, sha256_hex};

/// Represents the status of a C2PA verification check.
#[derive(Debug, Clone, PartialEq)]
pub enum C2paStatus {
    /// Cryptographic signature and pixel hash verified authentic.
    Verified,
    /// Image pixels have been modified/tampered since export.
    Tampered,
    /// Signature is missing or mathematically invalid.
    InvalidSignature,
    /// No C2PA manifest found in the image container.
    NoManifest,
}

/// Verification report extracted from an image with C2PA credentials.
#[derive(Debug, Clone, PartialEq)]
pub struct C2paReport {
    pub status: C2paStatus,
    pub title: String,
    pub claim_generator: String,
    pub signer_key_id: String,
    pub actions: Vec<String>,
    pub camera_metadata: String,
    pub recipe_hash: String,
    pub pixel_hash: String,
}

fn hex_decode_32(s: &str) -> Option<[u8; 32]> {
    if s.len() != 64 {
        return None;
    }
    let mut out = [0u8; 32];
    for i in 0..32 {
        out[i] = u8::from_str_radix(&s[i * 2..i * 2 + 2], 16).ok()?;
    }
    Some(out)
}

fn hex_decode_64(s: &str) -> Option<[u8; 64]> {
    if s.len() != 128 {
        return None;
    }
    let mut out = [0u8; 64];
    for i in 0..64 {
        out[i] = u8::from_str_radix(&s[i * 2..i * 2 + 2], 16).ok()?;
    }
    Some(out)
}

/// Generates a local device Ed25519 keypair seed and public key identifier.
pub fn generate_device_key(device_seed: &[u8]) -> (Vec<u8>, String) {
    let mut seed = [0u8; 32];
    if device_seed.len() == 32 {
        seed.copy_from_slice(device_seed);
    } else {
        seed = sha256(device_seed);
    }
    let public_key = crate::ed25519::public_key_from_seed(&seed);
    let mut pk_hex = String::with_capacity(64);
    for b in public_key {
        use std::fmt::Write;
        let _ = write!(pk_hex, "{:02x}", b);
    }
    let key_id = format!("c2pa:apx:{}", &pk_hex[..16]);
    (seed.to_vec(), key_id)
}

/// Computes the 64-character lowercase hex Ed25519 public key corresponding to a seed.
pub fn public_key_hex_from_seed(device_seed: &[u8]) -> String {
    let mut seed = [0u8; 32];
    if device_seed.len() == 32 {
        seed.copy_from_slice(device_seed);
    } else {
        seed = sha256(device_seed);
    }
    let public_key = crate::ed25519::public_key_from_seed(&seed);
    let mut pk_hex = String::with_capacity(64);
    for b in public_key {
        use std::fmt::Write;
        let _ = write!(pk_hex, "{:02x}", b);
    }
    pk_hex
}

/// Builds a canonical C2PA claim JSON containing edit actions, pixel hash, and EXIF summary.
pub fn build_c2pa_claim(
    pixel_hash_hex: &str,
    parent_hash_hex: Option<&str>,
    actions: &[&str],
    camera_metadata: &str,
    recipe_hash: &str,
    key_id: &str,
    public_key_hex: &str,
) -> String {
    let mut actions_json = String::new();
    for (i, act) in actions.iter().enumerate() {
        if i > 0 {
            actions_json.push_str(", ");
        }
        actions_json.push_str(&format!("\"{}\"", act));
    }

    let parent_entry = match parent_hash_hex {
        Some(h) => format!("\"parent_hash\": \"{}\", ", h),
        None => String::new(),
    };

    format!(
        "{{\"title\": \"ApertureX Content Credential\", \"claim_generator\": \"ApertureX/0.2.0 (True FOSS)\", \"signer\": \"{}\", \"public_key\": \"{}\", \"{}pixel_hash\": \"{}\", \"recipe_hash\": \"{}\", \"metadata\": \"{}\", \"actions\": [{}]}}",
        key_id, public_key_hex, parent_entry, pixel_hash_hex, recipe_hash, camera_metadata, actions_json
    )
}

/// Signs a canonical C2PA claim string with the local device private key using real Ed25519.
pub fn sign_c2pa_claim(claim_json: &str, private_key: &[u8]) -> String {
    let mut seed = [0u8; 32];
    if private_key.len() == 32 {
        seed.copy_from_slice(private_key);
    } else {
        seed = sha256(private_key);
    }
    let sig_bytes = crate::ed25519::sign_ed25519(&seed, claim_json.as_bytes());
    let mut s = String::with_capacity(128);
    for b in sig_bytes {
        use std::fmt::Write;
        let _ = write!(s, "{:02x}", b);
    }
    s
}

/// Embedded monochrome icon asset of ApertureX (1024x1024 PNG) used for C2PA claim generator branding.
pub static APERTUREX_ICON_PNG: &[u8] = include_bytes!("../../icons/app_icon_monochrome.png");

/// Packages a claim and its signature into a serializable C2PA manifest container with generator icon metadata.
pub fn create_c2pa_manifest(
    claim_json: &str,
    signature_hex: &str,
    key_id: &str,
    public_key_hex: &str,
) -> Vec<u8> {
    let container = format!(
        "{{\"c2pa_manifest\": {{\"claim\": {}, \"sig\": \"{}\", \"key_id\": \"{}\", \"public_key\": \"{}\", \"generator_icon\": \"icons/app_icon_monochrome.png\"}}}}",
        claim_json, signature_hex, key_id, public_key_hex
    );
    container.into_bytes()
}

const C2PA_APP11_HEADER: &[u8] = b"JP2C\x00\x00C2PA";

/// Injects a C2PA manifest as an APP11 marker segment into a JPEG byte stream.
pub fn inject_c2pa_app11(jpeg_bytes: Vec<u8>, manifest_bytes: &[u8]) -> Vec<u8> {
    if jpeg_bytes.len() < 4 || jpeg_bytes[0] != 0xFF || jpeg_bytes[1] != 0xD8 {
        return jpeg_bytes;
    }

    let segment_len = 2 + C2PA_APP11_HEADER.len() + manifest_bytes.len();
    if segment_len > 65535 {
        return jpeg_bytes; // Exceeds 64KB marker limit
    }

    let mut marker = Vec::with_capacity(4 + C2PA_APP11_HEADER.len() + manifest_bytes.len());
    marker.push(0xFF);
    marker.push(0xEB); // APP11
    marker.push((segment_len >> 8) as u8);
    marker.push((segment_len & 0xFF) as u8);
    marker.extend_from_slice(C2PA_APP11_HEADER);
    marker.extend_from_slice(manifest_bytes);

    // Find insertion point: directly after SOI (0xFF, 0xD8), or after existing APP0/APP1
    let mut insert_pos = 2usize.min(jpeg_bytes.len());
    let mut pos = 2;
    while pos + 4 <= jpeg_bytes.len() {
        if jpeg_bytes[pos] != 0xFF {
            break;
        }
        let marker_type = jpeg_bytes[pos + 1];
        if marker_type == 0xD9 || marker_type == 0xDA {
            // SOS or EOI reached
            break;
        }
        // Skip APP0 (0xE0) or APP1 (0xE1) to keep them first
        if marker_type == 0xE0 || marker_type == 0xE1 {
            let len = ((jpeg_bytes[pos + 2] as usize) << 8) | (jpeg_bytes[pos + 3] as usize);
            if len < 2 {
                break;
            }
            match pos.checked_add(2 + len) {
                Some(next) if next <= jpeg_bytes.len() => {
                    pos = next;
                    insert_pos = pos;
                }
                _ => break,
            }
        } else {
            break;
        }
    }
    insert_pos = insert_pos.min(jpeg_bytes.len());

    let mut out = Vec::with_capacity(jpeg_bytes.len() + marker.len());
    out.extend_from_slice(&jpeg_bytes[..insert_pos]);
    out.extend_from_slice(&marker);
    out.extend_from_slice(&jpeg_bytes[insert_pos..]);
    out
}

/// Extracts the raw C2PA manifest bytes from a JPEG container's APP11 marker.
pub fn extract_c2pa_app11(jpeg_bytes: &[u8]) -> Option<Vec<u8>> {
    if jpeg_bytes.len() < 4 || jpeg_bytes[0] != 0xFF || jpeg_bytes[1] != 0xD8 {
        return None;
    }

    let mut pos = 2;
    while pos + 4 <= jpeg_bytes.len() {
        if jpeg_bytes[pos] != 0xFF {
            pos += 1;
            continue;
        }
        let marker = jpeg_bytes[pos + 1];
        if marker == 0xDA || marker == 0xD9 {
            break; // Start of scan or end of image
        }
        let len = ((jpeg_bytes[pos + 2] as usize) << 8) | (jpeg_bytes[pos + 3] as usize);
        if len < 2 || pos + 2 + len > jpeg_bytes.len() {
            break;
        }

        if marker == 0xEB {
            // APP11 found
            let payload = &jpeg_bytes[pos + 4..pos + 2 + len];
            if payload.starts_with(C2PA_APP11_HEADER) {
                return Some(payload[C2PA_APP11_HEADER.len()..].to_vec());
            }
        }
        pos += 2 + len;
    }
    None
}

/// Verifies a JPEG image containing C2PA Content Credentials against the decoded pixel buffer.
pub fn verify_c2pa(
    jpeg_bytes: &[u8],
    decoded_rgba: &[u8],
    device_private_key: Option<&[u8]>,
) -> C2paReport {
    let manifest_bytes = match extract_c2pa_app11(jpeg_bytes) {
        Some(b) => b,
        None => {
            return C2paReport {
                status: C2paStatus::NoManifest,
                title: String::new(),
                claim_generator: String::new(),
                signer_key_id: String::new(),
                actions: Vec::new(),
                camera_metadata: String::new(),
                recipe_hash: String::new(),
                pixel_hash: String::new(),
            };
        }
    };

    let manifest_str = match std::str::from_utf8(&manifest_bytes) {
        Ok(s) => s,
        Err(_) => return report_invalid(),
    };

    // Parse claim JSON fields (lightweight, zero-dep extractor)
    let claim_str = match extract_json_object(manifest_str, "\"claim\":") {
        Some(s) => s,
        None => return report_invalid(),
    };

    let expected_sig = match extract_json_string(manifest_str, "\"sig\":") {
        Some(s) => s,
        None => return report_invalid(),
    };

    let key_id = extract_json_string(&claim_str, "\"signer\":").unwrap_or_default();
    let recorded_pixel_hash =
        extract_json_string(&claim_str, "\"pixel_hash\":").unwrap_or_default();
    let recipe_hash = extract_json_string(&claim_str, "\"recipe_hash\":").unwrap_or_default();
    let camera_meta = extract_json_string(&claim_str, "\"metadata\":").unwrap_or_default();
    let title = extract_json_string(&claim_str, "\"title\":")
        .unwrap_or_else(|| "Content Credential".to_string());
    let generator = extract_json_string(&claim_str, "\"claim_generator\":").unwrap_or_default();

    // Decode 64-byte Ed25519 signature
    let sig_bytes = match hex_decode_64(&expected_sig) {
        Some(b) => b,
        None => {
            return C2paReport {
                status: C2paStatus::InvalidSignature,
                title,
                claim_generator: generator,
                signer_key_id: key_id,
                actions: parse_actions(&claim_str),
                camera_metadata: camera_meta,
                recipe_hash,
                pixel_hash: recorded_pixel_hash,
            };
        }
    };

    // Extract embedded public key from claim or manifest
    let pk_hex_opt = extract_json_string(&claim_str, "\"public_key\":")
        .or_else(|| extract_json_string(manifest_str, "\"public_key\":"));

    let pk_bytes = match device_private_key {
        Some(priv_key) => {
            let mut seed = [0u8; 32];
            if priv_key.len() == 32 {
                seed.copy_from_slice(priv_key);
            } else {
                seed = sha256(priv_key);
            }
            let dev_pk = crate::ed25519::public_key_from_seed(&seed);
            if let Some(ref pk_hex) = pk_hex_opt {
                if let Some(embedded_pk) = hex_decode_32(pk_hex) {
                    if embedded_pk != dev_pk {
                        return C2paReport {
                            status: C2paStatus::InvalidSignature,
                            title,
                            claim_generator: generator,
                            signer_key_id: key_id,
                            actions: parse_actions(&claim_str),
                            camera_metadata: camera_meta,
                            recipe_hash,
                            pixel_hash: recorded_pixel_hash,
                        };
                    }
                }
            }
            dev_pk
        }
        None => match pk_hex_opt.and_then(|h| hex_decode_32(&h)) {
            Some(pk) => pk,
            None => {
                return C2paReport {
                    status: C2paStatus::InvalidSignature,
                    title,
                    claim_generator: generator,
                    signer_key_id: key_id,
                    actions: parse_actions(&claim_str),
                    camera_metadata: camera_meta,
                    recipe_hash,
                    pixel_hash: recorded_pixel_hash,
                };
            }
        },
    };

    // Mathematically verify Ed25519 signature over canonical claim string
    if !crate::ed25519::verify_ed25519(&pk_bytes, claim_str.as_bytes(), &sig_bytes) {
        return C2paReport {
            status: C2paStatus::InvalidSignature,
            title,
            claim_generator: generator,
            signer_key_id: key_id,
            actions: parse_actions(&claim_str),
            camera_metadata: camera_meta,
            recipe_hash,
            pixel_hash: recorded_pixel_hash,
        };
    }

    // Verify pixel hash
    let actual_pixel_hash = sha256_hex(decoded_rgba);
    let status = if actual_pixel_hash == recorded_pixel_hash {
        C2paStatus::Verified
    } else {
        C2paStatus::Tampered
    };

    C2paReport {
        status,
        title,
        claim_generator: generator,
        signer_key_id: key_id,
        actions: parse_actions(&claim_str),
        camera_metadata: camera_meta,
        recipe_hash,
        pixel_hash: actual_pixel_hash,
    }
}

fn report_invalid() -> C2paReport {
    C2paReport {
        status: C2paStatus::InvalidSignature,
        title: String::new(),
        claim_generator: String::new(),
        signer_key_id: String::new(),
        actions: Vec::new(),
        camera_metadata: String::new(),
        recipe_hash: String::new(),
        pixel_hash: String::new(),
    }
}

fn extract_json_string(json: &str, key: &str) -> Option<String> {
    let key_pos = json.find(key)?;
    let val_start = json[key_pos + key.len()..].find('"')? + key_pos + key.len() + 1;
    let val_end = json[val_start..].find('"')? + val_start;
    Some(json[val_start..val_end].to_string())
}

fn extract_json_object(json: &str, key: &str) -> Option<String> {
    let key_pos = json.find(key)?;
    let brace_start = json[key_pos + key.len()..].find('{')? + key_pos + key.len();
    let mut depth = 0;
    let mut end = brace_start;
    for (i, c) in json[brace_start..].char_indices() {
        if c == '{' {
            depth += 1;
        } else if c == '}' {
            depth -= 1;
            if depth == 0 {
                end = brace_start + i + 1;
                break;
            }
        }
    }
    if depth == 0 {
        Some(json[brace_start..end].to_string())
    } else {
        None
    }
}

fn parse_actions(claim_json: &str) -> Vec<String> {
    let mut list = Vec::new();
    if let Some(actions_pos) = claim_json.find("\"actions\": [") {
        let slice = &claim_json[actions_pos + 12..];
        if let Some(end_bracket) = slice.find(']') {
            let inner = &slice[..end_bracket];
            for part in inner.split(',') {
                let trimmed = part.trim().trim_matches('"');
                if !trimmed.is_empty() {
                    list.push(trimmed.to_string());
                }
            }
        }
    }
    list
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_device_key_generation() {
        let seed = b"test-device-uuid-123456";
        let (priv_key, key_id) = generate_device_key(seed);
        assert_eq!(priv_key.len(), 32);
        assert!(key_id.starts_with("c2pa:apx:"));
    }

    #[test]
    fn test_claim_signing_and_verification() {
        let seed = b"test-device-key";
        let (priv_key, key_id) = generate_device_key(seed);
        let pk_hex = public_key_hex_from_seed(&priv_key);

        let pixels = vec![128u8; 100 * 100 * 4];
        let pixel_hash = sha256_hex(&pixels);

        let claim = build_c2pa_claim(
            &pixel_hash,
            None,
            &["c2pa.opened", "c2pa.color_adjustments"],
            "Sony A7III • 35mm",
            "recipe_hash_abc",
            &key_id,
            &pk_hex,
        );

        let sig = sign_c2pa_claim(&claim, &priv_key);
        let manifest = create_c2pa_manifest(&claim, &sig, &key_id, &pk_hex);

        let dummy_jpeg = vec![
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1, 0, 1, 0,
            0, 0xFF, 0xD9,
        ];
        let injected = inject_c2pa_app11(dummy_jpeg, &manifest);

        // Verification with author private key should succeed
        let report = verify_c2pa(&injected, &pixels, Some(&priv_key));
        assert_eq!(report.status, C2paStatus::Verified);
        assert_eq!(report.signer_key_id, key_id);
        assert_eq!(report.actions.len(), 2);
        assert_eq!(report.camera_metadata, "Sony A7III • 35mm");

        // Verification without any private key (true offline public-key C2PA verification) must also succeed!
        let pub_report = verify_c2pa(&injected, &pixels, None);
        assert_eq!(pub_report.status, C2paStatus::Verified);
        assert_eq!(pub_report.signer_key_id, key_id);

        // Tampering with pixels must yield Tampered
        let mut tampered_pixels = pixels.clone();
        tampered_pixels[0] = 255;
        let tampered_report = verify_c2pa(&injected, &tampered_pixels, Some(&priv_key));
        assert_eq!(tampered_report.status, C2paStatus::Tampered);

        // Tampering with device key must yield InvalidSignature
        let wrong_key = vec![0u8; 32];
        let invalid_sig_report = verify_c2pa(&injected, &pixels, Some(&wrong_key));
        assert_eq!(invalid_sig_report.status, C2paStatus::InvalidSignature);

        // Tampering with claim text must fail signature verification even with None
        let mut tampered_jpeg = injected.clone();
        if let Some(pos) = tampered_jpeg.windows(7).position(|w| w == b"Apertur") {
            tampered_jpeg[pos] = b'X';
            let tampered_claim_report = verify_c2pa(&tampered_jpeg, &pixels, None);
            assert_eq!(tampered_claim_report.status, C2paStatus::InvalidSignature);
        }
    }
}
