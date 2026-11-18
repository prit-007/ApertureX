//! Depth field representation, caching, and serialization for ApertureX.

use std::sync::Arc;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DepthSource {
    EmbeddedGDepth,
    Neural,
    Approximate,
    None,
}

impl DepthSource {
    pub fn to_u8(self) -> u8 {
        match self {
            DepthSource::EmbeddedGDepth => 0,
            DepthSource::Neural => 1,
            DepthSource::Approximate => 2,
            DepthSource::None => 3,
        }
    }

    pub fn from_u8(val: u8) -> Self {
        match val {
            0 => DepthSource::EmbeddedGDepth,
            1 => DepthSource::Neural,
            2 => DepthSource::Approximate,
            _ => DepthSource::None,
        }
    }
}

/// Self-contained canonical depth field for an image.
#[derive(Debug, Clone, PartialEq)]
pub struct DepthField {
    pub plane: Arc<[f32]>,
    pub width: u32,
    pub height: u32,
    pub confidence: f32,
    pub source: DepthSource,
    pub model_id: Option<String>,
    pub content_hash: u64,
}

impl DepthField {
    pub fn new(
        plane: Vec<f32>,
        width: u32,
        height: u32,
        confidence: f32,
        source: DepthSource,
        model_id: Option<String>,
        content_hash: u64,
    ) -> Self {
        Self {
            plane: plane.into(),
            width,
            height,
            confidence: confidence.clamp(0.0, 1.0),
            source,
            model_id,
            content_hash,
        }
    }

    /// Serializes depth field to a compact binary format for sidecar storage.
    /// Header: magic (4B "AXDF") + version (2B) + width (4B) + height (4B) +
    /// confidence (4B f32) + source (1B) + content_hash (8B) + payload (w*h*4B f32).
    pub fn serialize_binary(&self) -> Vec<u8> {
        let mut buf = Vec::with_capacity(27 + self.plane.len() * 4);
        buf.extend_from_slice(b"AXDF");
        buf.extend_from_slice(&1u16.to_le_bytes()); // version 1
        buf.extend_from_slice(&self.width.to_le_bytes());
        buf.extend_from_slice(&self.height.to_le_bytes());
        buf.extend_from_slice(&self.confidence.to_le_bytes());
        buf.push(self.source.to_u8());
        buf.extend_from_slice(&self.content_hash.to_le_bytes());
        for &d in self.plane.iter() {
            buf.extend_from_slice(&d.to_le_bytes());
        }
        buf
    }

    /// Deserializes depth field from binary sidecar buffer.
    pub fn deserialize_binary(bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() < 27 {
            return Err("Depth sidecar payload too short".into());
        }
        if &bytes[0..4] != b"AXDF" {
            return Err("Invalid depth sidecar magic header".into());
        }
        let version = u16::from_le_bytes(bytes[4..6].try_into().unwrap());
        if version != 1 {
            return Err(format!("Unsupported depth sidecar version {version}"));
        }
        let width = u32::from_le_bytes(bytes[6..10].try_into().unwrap());
        let height = u32::from_le_bytes(bytes[10..14].try_into().unwrap());
        let confidence = f32::from_le_bytes(bytes[14..18].try_into().unwrap());
        let source = DepthSource::from_u8(bytes[18]);
        let content_hash = u64::from_le_bytes(bytes[19..27].try_into().unwrap());

        let expected_floats = (width as usize) * (height as usize);
        if bytes.len() < 27 + expected_floats * 4 {
            return Err("Truncated depth sidecar payload".into());
        }

        let mut plane = Vec::with_capacity(expected_floats);
        let mut offset = 27;
        for _ in 0..expected_floats {
            let val = f32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap());
            plane.push(val);
            offset += 4;
        }

        Ok(Self {
            plane: plane.into(),
            width,
            height,
            confidence,
            source,
            model_id: None,
            content_hash,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_depth_field_serialization_roundtrip() {
        let (w, h) = (4, 4);
        let plane: Vec<f32> = (0..16).map(|i| i as f32 / 16.0).collect();
        let field = DepthField::new(
            plane,
            w,
            h,
            0.85,
            DepthSource::Neural,
            Some("depth_anything_v2_vits".into()),
            0x1234_5678_9ABC_DEF0,
        );

        let bin = field.serialize_binary();
        assert_eq!(bin.len(), 27 + 16 * 4);

        let restored = DepthField::deserialize_binary(&bin).expect("deserialization must succeed");
        assert_eq!(restored.width, field.width);
        assert_eq!(restored.height, field.height);
        assert!((restored.confidence - field.confidence).abs() < 1e-6);
        assert_eq!(restored.source, field.source);
        assert_eq!(restored.content_hash, field.content_hash);
        assert_eq!(restored.plane.as_ref(), field.plane.as_ref());
    }

    #[test]
    fn test_depth_source_u8_roundtrip() {
        for src in [
            DepthSource::EmbeddedGDepth,
            DepthSource::Neural,
            DepthSource::Approximate,
            DepthSource::None,
        ] {
            assert_eq!(DepthSource::from_u8(src.to_u8()), src);
        }
    }
}
