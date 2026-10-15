//! RAW decode spike (ADR 0005). See docs/spikes/raw-engine-spike.md.

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use rawler::dng::writer::DngWriter;
    use rawler::dng::DngCompression;
    use rawler::rawsource::RawSource;

    fn make_dng(width: usize, height: usize) -> Vec<u8> {
        let data: Vec<u16> = (0..width * height * 3)
            .map(|i| ((i * 257) & 0xffff) as u16)
            .collect();
        let mut cursor = Cursor::new(Vec::new());
        {
            let mut w = DngWriter::new(&mut cursor, [1, 4, 0, 0]).unwrap();
            {
                let mut sub = w.subframe(0);
                sub.rgb_image_u16(&data, width, height, DngCompression::Uncompressed, 1)
                    .unwrap();
                sub.finalize().unwrap();
            }
            w.close().unwrap();
        }
        cursor.into_inner()
    }

    #[test]
    fn writer_reader_roundtrip() {
        let bytes = make_dng(16, 12);
        let src = RawSource::new_from_slice(&bytes);
        let img = rawler::decode(&src, &rawler::decoders::RawDecodeParams::default()).unwrap();
        assert_eq!((img.width, img.height), (16, 12));
        assert_eq!(img.cpp, 3);
    }
}

#[cfg(test)]
mod libraw_tests {
    #[test]
    fn libraw_is_available() {
        let _ = libraw::version();
    }
}

#[cfg(test)]
mod trait_spike {
    use crate::decode::{crop_rgba, DecodedImage};

    pub trait ImageSourceSpike {
        fn dimensions(&self) -> Result<(usize, usize), String>;
        fn decode_full_rgba(&self) -> Result<DecodedImage, String>;
        fn decode_roi(&self, x: usize, y: usize, w: usize, h: usize) -> Result<DecodedImage, String>;
    }

    struct Rb8 {
        data: Vec<u8>,
    }
    impl From<Vec<u8>> for Rb8 {
        fn from(v: Vec<u8>) -> Self {
            Rb8 { data: v }
        }
    }

    impl ImageSourceSpike for Rb8 {
        fn dimensions(&self) -> Result<(usize, usize), String> {
            let src = rawler::rawsource::RawSource::new_from_slice(&self.data);
            let img = rawler::decode(&src, &rawler::decoders::RawDecodeParams::default())
                .map_err(|e| format!("decode: {e:?}"))?;
            Ok((img.width, img.height))
        }
        fn decode_full_rgba(&self) -> Result<DecodedImage, String> {
            let src = rawler::rawsource::RawSource::new_from_slice(&self.data);
            let img = rawler::decode(&src, &rawler::decoders::RawDecodeParams::default())
                .map_err(|e| format!("decode: {e:?}"))?;
            let data = img.data.as_f32();
            let mut rgba = vec![0u8; img.width * img.height * 4];
            for i in 0..(img.width * img.height) {
                let v = data[i];
                let c = ((v * 255.0).clamp(0.0, 255.0) as u8);
                let idx = i * 4;
                rgba[idx] = c;
                rgba[idx + 1] = c;
                rgba[idx + 2] = c;
                rgba[idx + 3] = 255;
            }
            Ok(DecodedImage {
                width: img.width,
                height: img.height,
                rgba,
            })
        }
        fn decode_roi(&self, x: usize, y: usize, w: usize, h: usize) -> Result<DecodedImage, String> {
            let full = self.decode_full_rgba()?;
            crop_rgba(&full, x, y, w, h)
        }
    }

    #[test]
    fn rawler_spike_decodes_dng() {
        // use existing test helper logic
        use std::io::Cursor;
        use rawler::dng::writer::DngWriter;
        use rawler::dng::DngCompression;
        let data: Vec<u16> = (0..8 * 8 * 3).map(|i| ((i % 1024) as u16)).collect();
        let mut cursor = Cursor::new(Vec::new());
        {
            let mut w = DngWriter::new(&mut cursor, [1, 4, 0, 0]).unwrap();
            let mut sub = w.subframe(0);
            sub.rgb_image_u16(&data, 8, 8, DngCompression::Uncompressed, 1).unwrap();
            sub.finalize().unwrap();
            w.close().unwrap();
        }
        let dng = cursor.into_inner();
        let s: Rb8 = dng.into();
        assert_eq!(s.dimensions().unwrap(), (8, 8));
        assert_eq!(s.decode_roi(0, 0, 2, 2).unwrap().width, 2);
    }
    #[test]
    fn libraw_crate_linked() {
        let _v = libraw::version();
    }

}
