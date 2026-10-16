//! Writes a deterministic >100 MP JPEG corpus file for on-device tile/seam
//! profiling (#16). The same pattern as `AxEngine.syntheticJpeg`:
//!
//! ```sh
//! cargo run --release --example gen_corpus -- 12000 9000 /tmp/aperturex-corpus.jpg
//! flutter test integration_test/tile_corpus_test.dart -d <device>
//! ```
//!
//! Dimensions cap at u16 (the JPEG limit). The file is intentionally never
//! committed — regenerate it wherever it is needed.

use std::env;
use std::fs;
use std::process;
use std::time::Instant;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 4 {
        eprintln!("usage: gen_corpus <width> <height> <out.jpg>");
        process::exit(2);
    }
    let width: u32 = args[1].parse().unwrap_or_else(|_| {
        eprintln!("bad width: {}", args[1]);
        process::exit(2);
    });
    let height: u32 = args[2].parse().unwrap_or_else(|_| {
        eprintln!("bad height: {}", args[2]);
        process::exit(2);
    });
    let out_path = &args[3];

    let mp = (width as f64 * height as f64) / 1_000_000.0;
    eprintln!("generating {width}x{height} ({mp:.1} MP)…");
    let started = Instant::now();
    let jpeg = rust_lib_aperturex::api::engine::synthetic_jpeg(width, height);
    eprintln!(
        "encoded {} in {:.1}s, writing {out_path}…",
        human_bytes(jpeg.len()),
        started.elapsed().as_secs_f64()
    );
    fs::write(out_path, &jpeg).unwrap_or_else(|e| {
        eprintln!("write {out_path}: {e}");
        process::exit(1);
    });
    eprintln!("done");
}

fn human_bytes(n: usize) -> String {
    if n >= 1 << 20 {
        format!("{:.1} MiB", n as f64 / (1 << 20) as f64)
    } else if n >= 1 << 10 {
        format!("{:.1} KiB", n as f64 / (1 << 10) as f64)
    } else {
        format!("{n} B")
    }
}
