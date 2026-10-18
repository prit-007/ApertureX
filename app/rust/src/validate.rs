//! Validation helpers for FFI buffers and image dimensions.
//!
//! Prevents integer overflows, underflows, and slice-indexing panics
//! when crossing the `flutter_rust_bridge` boundary.

/// Validates that an RGBA buffer has at least `width * height * 4` bytes
/// without overflowing `usize`.
pub fn validate_rgba(rgba: &[u8], width: u32, height: u32) -> Result<(), String> {
    if width == 0 || height == 0 {
        return Err(format!("Dimensions must be non-zero: got {width}x{height}"));
    }
    let expected = (width as usize)
        .checked_mul(height as usize)
        .and_then(|px| px.checked_mul(4))
        .ok_or_else(|| format!("Dimensions overflow usize: {width}x{height}*4"))?;

    if rgba.len() < expected {
        return Err(format!(
            "RGBA buffer underflow: got {} bytes, expected at least {} for {width}x{height}",
            rgba.len(),
            expected
        ));
    }
    Ok(())
}

/// Validates that dimensions are within safe processing limits (<= max_dim).
pub fn validate_dimensions(width: u32, height: u32, max_dim: u32) -> Result<(), String> {
    if width == 0 || height == 0 {
        return Err(format!("Dimensions must be non-zero: got {width}x{height}"));
    }
    if width > max_dim || height > max_dim {
        return Err(format!(
            "Dimensions {width}x{height} exceed maximum allowed limit of {max_dim}"
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_rgba_valid() {
        let buf = vec![0u8; 100 * 50 * 4];
        assert!(validate_rgba(&buf, 100, 50).is_ok());
    }

    #[test]
    fn test_validate_rgba_underflow() {
        let buf = vec![0u8; 100 * 50 * 4 - 1];
        assert!(validate_rgba(&buf, 100, 50).is_err());
    }

    #[test]
    fn test_validate_rgba_zero_dims() {
        let buf = vec![0u8; 10];
        assert!(validate_rgba(&buf, 0, 50).is_err());
        assert!(validate_rgba(&buf, 50, 0).is_err());
    }

    #[test]
    fn test_validate_rgba_overflow() {
        let buf = vec![0u8; 10];
        assert!(validate_rgba(&buf, u32::MAX, u32::MAX).is_err());
    }

    #[test]
    fn test_validate_dimensions() {
        assert!(validate_dimensions(100, 100, 2048).is_ok());
        assert!(validate_dimensions(2049, 100, 2048).is_err());
        assert!(validate_dimensions(0, 100, 2048).is_err());
    }
}
