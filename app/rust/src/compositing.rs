//! Compositing and blend modes for Double Exposure and layer blending.

/// Blend modes for compositing two layers.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BlendMode {
    Normal = 0,
    Screen = 1,
    Multiply = 2,
    Overlay = 3,
    Lighten = 4,
    Darken = 5,
    Add = 6,
    Subtract = 7,
}

impl BlendMode {
    pub fn from_u32(idx: u32) -> Self {
        match idx {
            1 => BlendMode::Screen,
            2 => BlendMode::Multiply,
            3 => BlendMode::Overlay,
            4 => BlendMode::Lighten,
            5 => BlendMode::Darken,
            6 => BlendMode::Add,
            7 => BlendMode::Subtract,
            _ => BlendMode::Normal,
        }
    }
}

/// Blends a single RGB pixel `[r, g, b]` in 0.0..1.0.
#[inline]
pub fn blend_pixel(base: [f32; 3], overlay: [f32; 3], mode: BlendMode) -> [f32; 3] {
    let mut out = [0.0; 3];
    for i in 0..3 {
        let a = base[i];
        let b = overlay[i];
        out[i] = match mode {
            BlendMode::Normal => b,
            BlendMode::Screen => 1.0 - (1.0 - a) * (1.0 - b),
            BlendMode::Multiply => a * b,
            BlendMode::Overlay => {
                if a < 0.5 {
                    2.0 * a * b
                } else {
                    1.0 - 2.0 * (1.0 - a) * (1.0 - b)
                }
            }
            BlendMode::Lighten => a.max(b),
            BlendMode::Darken => a.min(b),
            BlendMode::Add => (a + b).min(1.0),
            BlendMode::Subtract => (a - b).max(0.0),
        };
    }
    out
}

/// Composites an overlay image onto base RGBA with the specified blend mode and opacity.
pub fn composite_layers(
    base_rgba: &[u8],
    overlay_rgba: &[u8],
    w: usize,
    h: usize,
    mode: BlendMode,
    opacity: f32,
) -> Vec<u8> {
    let opacity = opacity.clamp(0.0, 1.0);
    let total = (w * h * 4).min(base_rgba.len()).min(overlay_rgba.len());
    let mut out = base_rgba.to_vec();

    for idx in (0..total).step_by(4) {
        let b_r = base_rgba[idx] as f32 / 255.0;
        let b_g = base_rgba[idx + 1] as f32 / 255.0;
        let b_b = base_rgba[idx + 2] as f32 / 255.0;

        let o_r = overlay_rgba[idx] as f32 / 255.0;
        let o_g = overlay_rgba[idx + 1] as f32 / 255.0;
        let o_b = overlay_rgba[idx + 2] as f32 / 255.0;
        let o_a = (overlay_rgba[idx + 3] as f32 / 255.0) * opacity;

        if o_a <= 0.0 {
            continue;
        }

        let blended = blend_pixel([b_r, b_g, b_b], [o_r, o_g, o_b], mode);

        out[idx] = ((b_r * (1.0 - o_a) + blended[0] * o_a) * 255.0)
            .round()
            .clamp(0.0, 255.0) as u8;
        out[idx + 1] = ((b_g * (1.0 - o_a) + blended[1] * o_a) * 255.0)
            .round()
            .clamp(0.0, 255.0) as u8;
        out[idx + 2] = ((b_b * (1.0 - o_a) + blended[2] * o_a) * 255.0)
            .round()
            .clamp(0.0, 255.0) as u8;
    }

    out
}

/// Composites linear float buffers (scene-linear pipeline).
pub fn composite_layers_linear(
    base_linear: &[f32],
    overlay_linear: &[f32],
    mode: BlendMode,
    opacity: f32,
) -> Vec<f32> {
    let opacity = opacity.clamp(0.0, 1.0);
    let total = base_linear.len().min(overlay_linear.len());
    let mut out = base_linear.to_vec();

    for idx in (0..total).step_by(4) {
        let b_r = base_linear[idx];
        let b_g = base_linear[idx + 1];
        let b_b = base_linear[idx + 2];

        let o_r = overlay_linear[idx];
        let o_g = overlay_linear[idx + 1];
        let o_b = overlay_linear[idx + 2];
        let o_a = overlay_linear[idx + 3] * opacity;

        if o_a <= 0.0 {
            continue;
        }

        let blended = blend_pixel([b_r, b_g, b_b], [o_r, o_g, o_b], mode);

        out[idx] = (b_r * (1.0 - o_a) + blended[0] * o_a).max(0.0);
        out[idx + 1] = (b_g * (1.0 - o_a) + blended[1] * o_a).max(0.0);
        out[idx + 2] = (b_b * (1.0 - o_a) + blended[2] * o_a).max(0.0);
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_blend_modes() {
        let base = [0.5, 0.5, 0.5];
        let over = [0.8, 0.2, 0.5];

        let screen = blend_pixel(base, over, BlendMode::Screen);
        assert!(screen[0] >= 0.5);

        let mult = blend_pixel(base, over, BlendMode::Multiply);
        assert_eq!(mult[0], 0.4);

        let lighten = blend_pixel(base, over, BlendMode::Lighten);
        assert_eq!(lighten[0], 0.8);
        assert_eq!(lighten[1], 0.5);

        let darken = blend_pixel(base, over, BlendMode::Darken);
        assert_eq!(darken[0], 0.5);
        assert_eq!(darken[1], 0.2);
    }

    #[test]
    fn test_composite_layers_opacity() {
        let base = vec![100, 100, 100, 255];
        let over = vec![200, 200, 200, 255];

        let res0 = composite_layers(&base, &over, 1, 1, BlendMode::Normal, 0.0);
        assert_eq!(res0, base);

        let res1 = composite_layers(&base, &over, 1, 1, BlendMode::Normal, 1.0);
        assert_eq!(res1[0], 200);

        let res_half = composite_layers(&base, &over, 1, 1, BlendMode::Normal, 0.5);
        assert_eq!(res_half[0], 150);
    }
}
