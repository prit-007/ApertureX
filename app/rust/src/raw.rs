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
