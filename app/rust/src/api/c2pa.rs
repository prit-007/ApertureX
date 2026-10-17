//! C2PA (Content Credentials) API across the flutter_rust_bridge boundary.
//!
//! Exposes offline Ed25519 key generation and cryptographic provenance
//! verification for digital photojournalism and authenticity auditing.

#[derive(Debug, Clone)]
pub struct C2paDeviceInfo {
    pub private_key: Vec<u8>,
    pub key_id: String,
}

#[derive(Debug, Clone)]
pub struct C2paVerifyResult {
    pub status: String,
    pub is_valid: bool,
    pub title: String,
    pub claim_generator: String,
    pub signer_key_id: String,
    pub actions: Vec<String>,
    pub camera_metadata: String,
    pub recipe_hash: String,
    pub pixel_hash: String,
    pub status_message: String,
}

/// Generates a local device key (32-byte cryptographic seed) for signing.
pub fn c2pa_generate_device_key(device_seed: Vec<u8>) -> C2paDeviceInfo {
    let (key, id) = crate::c2pa::generate_device_key(&device_seed);
    C2paDeviceInfo {
        private_key: key,
        key_id: id,
    }
}

/// Verifies cryptographic C2PA provenance, pixel hash integrity, and signature.
pub fn c2pa_verify_image(
    image_bytes: Vec<u8>,
    device_private_key: Option<Vec<u8>>,
) -> C2paVerifyResult {
    let decoded_rgba = match crate::decode::decode_rgba(&image_bytes) {
        Ok(img) => img.rgba,
        Err(_) => Vec::new(),
    };

    let report =
        crate::c2pa::verify_c2pa(&image_bytes, &decoded_rgba, device_private_key.as_deref());
    let status_str = match report.status {
        crate::c2pa::C2paStatus::Verified => "Verified",
        crate::c2pa::C2paStatus::Tampered => "Tampered",
        crate::c2pa::C2paStatus::InvalidSignature => "InvalidSignature",
        crate::c2pa::C2paStatus::NoManifest => "NoManifest",
    };

    let msg = match report.status {
        crate::c2pa::C2paStatus::Verified => {
            "Content Credentials verified. Cryptographic signature and pixel hash confirmed authentic.".to_string()
        }
        crate::c2pa::C2paStatus::Tampered => {
            "Tampering detected! The image pixels have been altered since export.".to_string()
        }
        crate::c2pa::C2paStatus::InvalidSignature => {
            "Signature verification failed for the given device key.".to_string()
        }
        crate::c2pa::C2paStatus::NoManifest => {
            "No C2PA Content Credentials manifest found in this image.".to_string()
        }
    };

    C2paVerifyResult {
        status: status_str.to_string(),
        is_valid: report.status == crate::c2pa::C2paStatus::Verified,
        title: report.title,
        claim_generator: report.claim_generator,
        signer_key_id: report.signer_key_id,
        actions: report.actions,
        camera_metadata: report.camera_metadata,
        recipe_hash: report.recipe_hash,
        pixel_hash: report.pixel_hash,
        status_message: msg,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_c2pa_api_generate_and_verify_invalid() {
        let info = c2pa_generate_device_key(vec![42u8; 32]);
        assert_eq!(info.private_key.len(), 32);
        assert!(info.key_id.starts_with("c2pa:apx:"));

        let garbage = vec![0u8; 100];
        let result = c2pa_verify_image(garbage, None);
        assert!(!result.is_valid);
        assert_eq!(result.status, "NoManifest");
    }
}
