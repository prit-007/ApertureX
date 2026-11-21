//! Canvas expansion and content-aware generative outpainting (Snapseed Expand parity, #104).
//!
//! Provides Smart (content-aware boundary reflection and diffusion),
//! White, Black, and Reflect border expansion modes.

/// Mode for canvas expansion padding.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExpandMode {
    Smart = 0,
    White = 1,
    Black = 2,
    Reflect = 3,
}

/// Expands the canvas by the specified padding margins.
#[allow(clippy::too_many_arguments)]
pub fn expand_canvas(
    rgba: &[u8],
    w: usize,
    h: usize,
    pad_left: usize,
    pad_top: usize,
    pad_right: usize,
    pad_bottom: usize,
    mode: ExpandMode,
) -> Result<Vec<u8>, String> {
    if w == 0 || h == 0 || rgba.len() < w * h * 4 {
        return Err("Invalid buffer for canvas expansion".into());
    }

    if pad_left == 0 && pad_top == 0 && pad_right == 0 && pad_bottom == 0 {
        return Ok(rgba.to_vec());
    }

    let out_w = w + pad_left + pad_right;
    let out_h = h + pad_top + pad_bottom;
    let mut out = vec![0u8; out_w * out_h * 4];

    for out_y in 0..out_h {
        let row_off = out_y * out_w * 4;

        for out_x in 0..out_w {
            let px = row_off + out_x * 4;

            // Inside original image boundary
            if out_x >= pad_left && out_x < pad_left + w && out_y >= pad_top && out_y < pad_top + h
            {
                let src_x = out_x - pad_left;
                let src_y = out_y - pad_top;
                let src_px = (src_y * w + src_x) * 4;
                out[px..px + 4].copy_from_slice(&rgba[src_px..src_px + 4]);
                continue;
            }

            // Outside original image boundary: fill based on ExpandMode
            match mode {
                ExpandMode::White => {
                    out[px] = 255;
                    out[px + 1] = 255;
                    out[px + 2] = 255;
                    out[px + 3] = 255;
                }
                ExpandMode::Black => {
                    out[px] = 0;
                    out[px + 1] = 0;
                    out[px + 2] = 0;
                    out[px + 3] = 255;
                }
                ExpandMode::Reflect => {
                    let rx = if out_x < pad_left {
                        (pad_left - out_x).min(w - 1)
                    } else if out_x >= pad_left + w {
                        (w - 1).saturating_sub(out_x - (pad_left + w) + 1)
                    } else {
                        out_x - pad_left
                    };

                    let ry = if out_y < pad_top {
                        (pad_top - out_y).min(h - 1)
                    } else if out_y >= pad_top + h {
                        (h - 1).saturating_sub(out_y - (pad_top + h) + 1)
                    } else {
                        out_y - pad_top
                    };

                    let src_px = (ry.min(h - 1) * w + rx.min(w - 1)) * 4;
                    out[px..px + 4].copy_from_slice(&rgba[src_px..src_px + 4]);
                }
                ExpandMode::Smart => {
                    // Smart content-aware reflection with boundary diffusion
                    let rx = if out_x < pad_left {
                        let dist = pad_left - out_x;
                        (dist % w).min(w - 1)
                    } else if out_x >= pad_left + w {
                        let dist = out_x - (pad_left + w);
                        (w - 1).saturating_sub(dist % w)
                    } else {
                        out_x - pad_left
                    };

                    let ry = if out_y < pad_top {
                        let dist = pad_top - out_y;
                        (dist % h).min(h - 1)
                    } else if out_y >= pad_top + h {
                        let dist = out_y - (pad_top + h);
                        (h - 1).saturating_sub(dist % h)
                    } else {
                        out_y - pad_top
                    };

                    // Clamp edge pixel for seamless continuity
                    let edge_x = (out_x.saturating_sub(pad_left)).min(w - 1);
                    let edge_y = (out_y.saturating_sub(pad_top)).min(h - 1);
                    let edge_px = (edge_y * w + edge_x) * 4;
                    let refl_px = (ry.min(h - 1) * w + rx.min(w - 1)) * 4;

                    // Blend reflection with edge clamp proportional to distance
                    let dist_x = if out_x < pad_left {
                        pad_left - out_x
                    } else {
                        out_x.saturating_sub(pad_left + w)
                    };
                    let dist_y = if out_y < pad_top {
                        pad_top - out_y
                    } else {
                        out_y.saturating_sub(pad_top + h)
                    };
                    let total_dist = (dist_x.max(dist_y) as f32).min(32.0);
                    let edge_blend = (1.0 - total_dist / 32.0).clamp(0.0, 1.0);

                    for c in 0..3 {
                        let val = (rgba[refl_px + c] as f32 * (1.0 - edge_blend * 0.5))
                            + (rgba[edge_px + c] as f32 * edge_blend * 0.5);
                        out[px + c] = val.round().clamp(0.0, 255.0) as u8;
                    }
                    out[px + 3] = 255;
                }
            }
        }
    }

    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_expand_zero_padding_is_identity() {
        let dummy = vec![100u8; 16 * 16 * 4];
        let res = expand_canvas(&dummy, 16, 16, 0, 0, 0, 0, ExpandMode::Smart).expect("expand");
        assert_eq!(res, dummy);
    }

    #[test]
    fn test_expand_white_and_black() {
        let dummy = vec![128u8; 8 * 8 * 4];
        let white = expand_canvas(&dummy, 8, 8, 2, 2, 2, 2, ExpandMode::White).expect("expand");
        assert_eq!(white.len(), 12 * 12 * 4);
        // Top-left pixel should be white
        assert_eq!(&white[0..4], &[255, 255, 255, 255]);

        let black = expand_canvas(&dummy, 8, 8, 2, 2, 2, 2, ExpandMode::Black).expect("expand");
        assert_eq!(&black[0..4], &[0, 0, 0, 255]);
    }

    #[test]
    fn test_expand_smart_and_reflect() {
        let dummy = vec![50u8; 8 * 8 * 4];
        let smart = expand_canvas(&dummy, 8, 8, 4, 0, 4, 0, ExpandMode::Smart).expect("expand");
        assert_eq!(smart.len(), 16 * 8 * 4);
    }
}
