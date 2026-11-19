//! Flutter Rust Bridge API for canvas expansion & smart outpainting (#104).

use crate::expand::{expand_canvas as core_expand, ExpandMode};

#[allow(clippy::too_many_arguments)]
pub fn expand_canvas(
    rgba: Vec<u8>,
    width: u32,
    height: u32,
    pad_left: u32,
    pad_top: u32,
    pad_right: u32,
    pad_bottom: u32,
    mode_index: u32,
) -> Result<Vec<u8>, String> {
    let mode = match mode_index {
        1 => ExpandMode::White,
        2 => ExpandMode::Black,
        3 => ExpandMode::Reflect,
        _ => ExpandMode::Smart,
    };

    core_expand(
        &rgba,
        width as usize,
        height as usize,
        pad_left as usize,
        pad_top as usize,
        pad_right as usize,
        pad_bottom as usize,
        mode,
    )
}
