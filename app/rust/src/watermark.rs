//! Pure-Rust Watermark, Museum Frame (EXIF Print), and Typography Engine.
//!
//! Provides resolution-independent antialiased vector typography,
//! exhibition gallery mats (Museum Frames) with EXIF camera/lens metadata,
//! custom photographer text and PNG logo signatures with 9-point grid anchors,
//! and the opt-in "FOSS Flex" badge. 100% offline with zero C-dependencies.

/// Anchor alignment for watermarks and signatures.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WatermarkAnchor {
    TopLeft,
    TopCenter,
    TopRight,
    CenterLeft,
    Center,
    CenterRight,
    BottomLeft,
    BottomCenter,
    BottomRight,
}

/// Color theme for the exhibition Museum Frame.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MuseumFrameTheme {
    StudioWhite,
    MatteDark,
    WarmGallery,
}

impl MuseumFrameTheme {
    pub fn bg_rgba(self) -> [u8; 4] {
        match self {
            MuseumFrameTheme::StudioWhite => [255, 255, 255, 255],
            MuseumFrameTheme::MatteDark => [20, 20, 20, 255],
            MuseumFrameTheme::WarmGallery => [247, 245, 240, 255],
        }
    }

    pub fn text_primary_rgba(self) -> [u8; 4] {
        match self {
            MuseumFrameTheme::StudioWhite => [26, 26, 26, 255],
            MuseumFrameTheme::MatteDark => [240, 240, 240, 255],
            MuseumFrameTheme::WarmGallery => [43, 41, 39, 255],
        }
    }

    pub fn text_secondary_rgba(self) -> [u8; 4] {
        match self {
            MuseumFrameTheme::StudioWhite => [120, 120, 120, 255],
            MuseumFrameTheme::MatteDark => [160, 160, 160, 255],
            MuseumFrameTheme::WarmGallery => [130, 126, 120, 255],
        }
    }
}

/// Specification for custom branding and watermarking.
#[derive(Debug, Clone, PartialEq)]
pub struct WatermarkSpec {
    // Museum Frame
    pub enable_museum_frame: bool,
    pub frame_theme: MuseumFrameTheme,
    pub exif_line1: String, // e.g. "SONY ILCE-7M3 • FE 35mm F1.4 GM"
    pub exif_line2: String, // e.g. "35mm • 1/250s • f/2.0 • ISO 100"

    // Custom Signature
    pub enable_signature: bool,
    pub signature_text: String,
    pub signature_anchor: WatermarkAnchor,
    pub signature_opacity: f32,  // 0.0 to 1.0
    pub signature_size_pct: f32, // e.g. 2.5% of shortest side

    // PNG Logo Signature
    pub enable_logo: bool,
    pub logo_bytes: Vec<u8>,
    pub logo_anchor: WatermarkAnchor,
    pub logo_opacity: f32,
    pub logo_scale_pct: f32, // e.g. 10.0% of width

    // FOSS Flex Badge
    pub enable_foss_badge: bool,
}

impl Default for WatermarkSpec {
    fn default() -> Self {
        Self {
            enable_museum_frame: false,
            frame_theme: MuseumFrameTheme::StudioWhite,
            exif_line1: String::new(),
            exif_line2: String::new(),
            enable_signature: false,
            signature_text: String::new(),
            signature_anchor: WatermarkAnchor::BottomRight,
            signature_opacity: 0.8,
            signature_size_pct: 2.5,
            enable_logo: false,
            logo_bytes: Vec::new(),
            logo_anchor: WatermarkAnchor::BottomRight,
            logo_opacity: 0.8,
            logo_scale_pct: 10.0,
            enable_foss_badge: false,
        }
    }
}

// ---------------------------------------------------------------------------
// Vector Stroke Font Rasterizer
// ---------------------------------------------------------------------------

type Stroke = (f32, f32, f32, f32); // (x1, y1, x2, y2) in 0..advance x 0..100

/// Returns the horizontal advance width and vector strokes for a given character.
fn glyph_definition(c: char) -> (f32, &'static [Stroke]) {
    match c {
        'A' => (
            60.0,
            &[
                (10.0, 100.0, 30.0, 10.0),
                (30.0, 10.0, 50.0, 100.0),
                (18.0, 68.0, 42.0, 68.0),
            ],
        ),
        'B' => (
            55.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (12.0, 10.0, 38.0, 10.0),
                (38.0, 10.0, 46.0, 28.0),
                (46.0, 28.0, 38.0, 52.0),
                (38.0, 52.0, 12.0, 52.0),
                (12.0, 52.0, 40.0, 52.0),
                (40.0, 52.0, 48.0, 74.0),
                (48.0, 74.0, 40.0, 100.0),
                (40.0, 100.0, 12.0, 100.0),
            ],
        ),
        'C' => (
            55.0,
            &[
                (48.0, 25.0, 35.0, 10.0),
                (35.0, 10.0, 22.0, 10.0),
                (22.0, 10.0, 10.0, 28.0),
                (10.0, 28.0, 10.0, 82.0),
                (10.0, 82.0, 22.0, 100.0),
                (22.0, 100.0, 35.0, 100.0),
                (35.0, 100.0, 48.0, 85.0),
            ],
        ),
        'D' => (
            58.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (12.0, 10.0, 35.0, 10.0),
                (35.0, 10.0, 48.0, 30.0),
                (48.0, 30.0, 48.0, 80.0),
                (48.0, 80.0, 35.0, 100.0),
                (35.0, 100.0, 12.0, 100.0),
            ],
        ),
        'E' => (
            50.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (12.0, 10.0, 42.0, 10.0),
                (12.0, 55.0, 36.0, 55.0),
                (12.0, 100.0, 42.0, 100.0),
            ],
        ),
        'F' => (
            48.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (12.0, 10.0, 42.0, 10.0),
                (12.0, 55.0, 34.0, 55.0),
            ],
        ),
        'G' => (
            58.0,
            &[
                (48.0, 25.0, 35.0, 10.0),
                (35.0, 10.0, 22.0, 10.0),
                (22.0, 10.0, 10.0, 28.0),
                (10.0, 28.0, 10.0, 82.0),
                (10.0, 82.0, 22.0, 100.0),
                (22.0, 100.0, 38.0, 100.0),
                (38.0, 100.0, 48.0, 85.0),
                (48.0, 85.0, 48.0, 55.0),
                (48.0, 55.0, 30.0, 55.0),
            ],
        ),
        'H' => (
            58.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (46.0, 10.0, 46.0, 100.0),
                (12.0, 55.0, 46.0, 55.0),
            ],
        ),
        'I' => (
            24.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (4.0, 10.0, 20.0, 10.0),
                (4.0, 100.0, 20.0, 100.0),
            ],
        ),
        'J' => (
            45.0,
            &[
                (34.0, 10.0, 34.0, 82.0),
                (34.0, 82.0, 24.0, 100.0),
                (24.0, 100.0, 10.0, 92.0),
                (10.0, 92.0, 8.0, 75.0),
            ],
        ),
        'K' => (
            54.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (44.0, 10.0, 14.0, 60.0),
                (18.0, 55.0, 46.0, 100.0),
            ],
        ),
        'L' => (
            46.0,
            &[(12.0, 10.0, 12.0, 100.0), (12.0, 100.0, 40.0, 100.0)],
        ),
        'M' => (
            68.0,
            &[
                (12.0, 100.0, 12.0, 10.0),
                (12.0, 10.0, 34.0, 70.0),
                (34.0, 70.0, 56.0, 10.0),
                (56.0, 10.0, 56.0, 100.0),
            ],
        ),
        'N' => (
            58.0,
            &[
                (12.0, 100.0, 12.0, 10.0),
                (12.0, 10.0, 46.0, 100.0),
                (46.0, 100.0, 46.0, 10.0),
            ],
        ),
        'O' => (
            60.0,
            &[
                (20.0, 10.0, 40.0, 10.0),
                (40.0, 10.0, 50.0, 28.0),
                (50.0, 28.0, 50.0, 82.0),
                (50.0, 82.0, 40.0, 100.0),
                (40.0, 100.0, 20.0, 100.0),
                (20.0, 100.0, 10.0, 82.0),
                (10.0, 82.0, 10.0, 28.0),
                (10.0, 28.0, 20.0, 10.0),
            ],
        ),
        'P' => (
            52.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (12.0, 10.0, 36.0, 10.0),
                (36.0, 10.0, 44.0, 26.0),
                (44.0, 26.0, 36.0, 55.0),
                (36.0, 55.0, 12.0, 55.0),
            ],
        ),
        'Q' => (
            60.0,
            &[
                (20.0, 10.0, 40.0, 10.0),
                (40.0, 10.0, 50.0, 28.0),
                (50.0, 28.0, 50.0, 82.0),
                (50.0, 82.0, 40.0, 100.0),
                (40.0, 100.0, 20.0, 100.0),
                (20.0, 100.0, 10.0, 82.0),
                (10.0, 82.0, 10.0, 28.0),
                (10.0, 28.0, 20.0, 10.0),
                (36.0, 76.0, 52.0, 106.0),
            ],
        ),
        'R' => (
            55.0,
            &[
                (12.0, 10.0, 12.0, 100.0),
                (12.0, 10.0, 36.0, 10.0),
                (36.0, 10.0, 46.0, 26.0),
                (46.0, 26.0, 36.0, 55.0),
                (36.0, 55.0, 12.0, 55.0),
                (32.0, 55.0, 46.0, 100.0),
            ],
        ),
        'S' => (
            52.0,
            &[
                (44.0, 22.0, 34.0, 10.0),
                (34.0, 10.0, 20.0, 10.0),
                (20.0, 10.0, 10.0, 24.0),
                (10.0, 24.0, 18.0, 48.0),
                (18.0, 48.0, 38.0, 58.0),
                (38.0, 58.0, 44.0, 80.0),
                (44.0, 80.0, 34.0, 100.0),
                (34.0, 100.0, 18.0, 100.0),
                (18.0, 100.0, 8.0, 86.0),
            ],
        ),
        'T' => (52.0, &[(6.0, 10.0, 46.0, 10.0), (26.0, 10.0, 26.0, 100.0)]),
        'U' => (
            56.0,
            &[
                (12.0, 10.0, 12.0, 80.0),
                (12.0, 80.0, 24.0, 100.0),
                (24.0, 100.0, 36.0, 100.0),
                (36.0, 100.0, 46.0, 80.0),
                (46.0, 80.0, 46.0, 10.0),
            ],
        ),
        'V' => (
            56.0,
            &[(10.0, 10.0, 28.0, 100.0), (28.0, 100.0, 46.0, 10.0)],
        ),
        'W' => (
            72.0,
            &[
                (8.0, 10.0, 20.0, 100.0),
                (20.0, 100.0, 36.0, 40.0),
                (36.0, 40.0, 52.0, 100.0),
                (52.0, 100.0, 64.0, 10.0),
            ],
        ),
        'X' => (
            54.0,
            &[(10.0, 10.0, 44.0, 100.0), (44.0, 10.0, 10.0, 100.0)],
        ),
        'Y' => (
            52.0,
            &[
                (10.0, 10.0, 26.0, 55.0),
                (42.0, 10.0, 26.0, 55.0),
                (26.0, 55.0, 26.0, 100.0),
            ],
        ),
        'Z' => (
            52.0,
            &[
                (10.0, 10.0, 44.0, 10.0),
                (44.0, 10.0, 10.0, 100.0),
                (10.0, 100.0, 44.0, 100.0),
            ],
        ),

        // Digits
        '0' => (
            52.0,
            &[
                (18.0, 10.0, 34.0, 10.0),
                (34.0, 10.0, 44.0, 28.0),
                (44.0, 28.0, 44.0, 82.0),
                (44.0, 82.0, 34.0, 100.0),
                (34.0, 100.0, 18.0, 100.0),
                (18.0, 100.0, 8.0, 82.0),
                (8.0, 82.0, 8.0, 28.0),
                (8.0, 28.0, 18.0, 10.0),
                (42.0, 16.0, 10.0, 94.0),
            ],
        ),
        '1' => (
            32.0,
            &[
                (8.0, 30.0, 20.0, 10.0),
                (20.0, 10.0, 20.0, 100.0),
                (8.0, 100.0, 30.0, 100.0),
            ],
        ),
        '2' => (
            50.0,
            &[
                (10.0, 26.0, 20.0, 10.0),
                (20.0, 10.0, 34.0, 10.0),
                (34.0, 10.0, 42.0, 24.0),
                (42.0, 24.0, 10.0, 100.0),
                (10.0, 100.0, 44.0, 100.0),
            ],
        ),
        '3' => (
            50.0,
            &[
                (10.0, 14.0, 40.0, 14.0),
                (40.0, 14.0, 24.0, 50.0),
                (24.0, 50.0, 38.0, 54.0),
                (38.0, 54.0, 44.0, 74.0),
                (44.0, 74.0, 36.0, 100.0),
                (36.0, 100.0, 14.0, 100.0),
                (14.0, 100.0, 8.0, 88.0),
            ],
        ),
        '4' => (
            52.0,
            &[
                (34.0, 10.0, 8.0, 68.0),
                (8.0, 68.0, 46.0, 68.0),
                (34.0, 35.0, 34.0, 100.0),
            ],
        ),
        '5' => (
            50.0,
            &[
                (40.0, 12.0, 12.0, 12.0),
                (12.0, 12.0, 10.0, 50.0),
                (10.0, 50.0, 32.0, 46.0),
                (32.0, 46.0, 42.0, 66.0),
                (42.0, 66.0, 36.0, 100.0),
                (36.0, 100.0, 14.0, 100.0),
                (14.0, 100.0, 8.0, 86.0),
            ],
        ),
        '6' => (
            50.0,
            &[
                (36.0, 16.0, 24.0, 10.0),
                (24.0, 10.0, 12.0, 30.0),
                (12.0, 30.0, 12.0, 80.0),
                (12.0, 80.0, 24.0, 100.0),
                (24.0, 100.0, 36.0, 100.0),
                (36.0, 100.0, 42.0, 82.0),
                (42.0, 82.0, 36.0, 55.0),
                (36.0, 55.0, 14.0, 55.0),
            ],
        ),
        '7' => (50.0, &[(8.0, 10.0, 44.0, 10.0), (44.0, 10.0, 20.0, 100.0)]),
        '8' => (
            52.0,
            &[
                (26.0, 10.0, 14.0, 22.0),
                (14.0, 22.0, 26.0, 52.0),
                (26.0, 52.0, 10.0, 72.0),
                (10.0, 72.0, 26.0, 100.0),
                (26.0, 100.0, 42.0, 72.0),
                (42.0, 72.0, 26.0, 52.0),
                (26.0, 52.0, 38.0, 22.0),
                (38.0, 22.0, 26.0, 10.0),
            ],
        ),
        '9' => (
            50.0,
            &[
                (36.0, 50.0, 14.0, 50.0),
                (14.0, 50.0, 8.0, 28.0),
                (8.0, 28.0, 18.0, 10.0),
                (18.0, 10.0, 34.0, 10.0),
                (34.0, 10.0, 42.0, 26.0),
                (42.0, 26.0, 42.0, 80.0),
                (42.0, 80.0, 30.0, 100.0),
                (30.0, 100.0, 16.0, 94.0),
            ],
        ),

        // Common symbols
        '/' => (38.0, &[(8.0, 100.0, 30.0, 10.0)]),
        '.' => (20.0, &[(10.0, 92.0, 10.0, 100.0)]),
        ',' => (20.0, &[(10.0, 90.0, 6.0, 106.0)]),
        ':' => (20.0, &[(10.0, 42.0, 10.0, 50.0), (10.0, 92.0, 10.0, 100.0)]),
        '-' => (32.0, &[(6.0, 55.0, 26.0, 55.0)]),
        '_' => (40.0, &[(4.0, 102.0, 36.0, 102.0)]),
        '|' => (20.0, &[(10.0, 5.0, 10.0, 105.0)]),
        '+' => (44.0, &[(8.0, 55.0, 36.0, 55.0), (22.0, 27.0, 22.0, 83.0)]),
        '%' => (
            60.0,
            &[
                (12.0, 95.0, 48.0, 15.0),
                (18.0, 25.0, 18.0, 35.0),
                (42.0, 75.0, 42.0, 85.0),
            ],
        ),
        '(' => (24.0, &[(18.0, 10.0, 8.0, 55.0), (8.0, 55.0, 18.0, 100.0)]),
        ')' => (24.0, &[(8.0, 10.0, 18.0, 55.0), (18.0, 55.0, 8.0, 100.0)]),
        '\'' => (16.0, &[(8.0, 10.0, 8.0, 30.0)]),
        '"' => (26.0, &[(8.0, 10.0, 8.0, 30.0), (18.0, 10.0, 18.0, 30.0)]),

        // Pro Photography Symbols
        '•' => (30.0, &[(15.0, 50.0, 15.0, 60.0), (10.0, 55.0, 20.0, 55.0)]),
        '°' => (
            28.0,
            &[
                (10.0, 15.0, 18.0, 15.0),
                (18.0, 15.0, 18.0, 32.0),
                (18.0, 32.0, 10.0, 32.0),
                (10.0, 32.0, 10.0, 15.0),
            ],
        ),
        '©' => (
            64.0,
            &[
                // Outer ring
                (20.0, 10.0, 44.0, 10.0),
                (44.0, 10.0, 54.0, 28.0),
                (54.0, 28.0, 54.0, 82.0),
                (54.0, 82.0, 44.0, 100.0),
                (44.0, 100.0, 20.0, 100.0),
                (20.0, 100.0, 10.0, 82.0),
                (10.0, 82.0, 10.0, 28.0),
                (10.0, 28.0, 20.0, 10.0),
                // Inner 'C'
                (40.0, 38.0, 30.0, 30.0),
                (30.0, 30.0, 22.0, 42.0),
                (22.0, 42.0, 22.0, 68.0),
                (22.0, 68.0, 30.0, 80.0),
                (30.0, 80.0, 40.0, 72.0),
            ],
        ),
        '⬡' => (
            60.0,
            &[
                // Hexagon monogram
                (30.0, 8.0, 54.0, 26.0),
                (54.0, 26.0, 54.0, 84.0),
                (54.0, 84.0, 30.0, 102.0),
                (30.0, 102.0, 6.0, 84.0),
                (6.0, 84.0, 6.0, 26.0),
                (6.0, 26.0, 30.0, 8.0),
            ],
        ),
        ' ' => (30.0, &[]),

        // Lowercase letters (clean small-caps styling for pro editorial typography)
        other => {
            let upper = other.to_ascii_uppercase();
            if upper != other {
                let (w, strokes) = glyph_definition(upper);
                (w * 0.85, strokes)
            } else {
                (30.0, &[])
            }
        }
    }
}

/// Measures the rendered width and height of a string at `font_size_px`.
pub fn measure_text(text: &str, font_size_px: f32) -> (f32, f32) {
    let scale = font_size_px / 100.0;
    let mut total_w = 0.0f32;
    for c in text.chars() {
        let (advance, _) = glyph_definition(c);
        total_w += advance * scale + (font_size_px * 0.05); // slight tracking
    }
    (total_w, font_size_px)
}

/// Distance from point (px, py) to line segment (x1, y1)-(x2, y2).
#[inline]
fn dist_to_segment(px: f32, py: f32, x1: f32, y1: f32, x2: f32, y2: f32) -> f32 {
    let dx = x2 - x1;
    let dy = y2 - y1;
    let l2 = dx * dx + dy * dy;
    if l2 == 0.0 {
        return ((px - x1) * (px - x1) + (py - y1) * (py - y1)).sqrt();
    }
    let t = (((px - x1) * dx + (py - y1) * dy) / l2).clamp(0.0, 1.0);
    let proj_x = x1 + t * dx;
    let proj_y = y1 + t * dy;
    ((px - proj_x) * (px - proj_x) + (py - proj_y) * (py - proj_y)).sqrt()
}

/// Draws resolution-independent antialiased text onto an RGBA buffer.
#[allow(clippy::too_many_arguments)]
pub fn draw_text_rgba(
    buf: &mut [u8],
    w: u32,
    h: u32,
    text: &str,
    start_x: f32,
    start_y: f32,
    font_size_px: f32,
    color: [u8; 4],
    drop_shadow: bool,
) {
    if font_size_px <= 1.0 || text.is_empty() {
        return;
    }

    if drop_shadow {
        // Draw soft contrast shadow offset by 1-2 pixels
        let shadow_offset = (font_size_px * 0.04).max(1.0);
        let shadow_color = if color[0] as u16 + color[1] as u16 + color[2] as u16 > 380 {
            [10, 10, 10, (color[3] as f32 * 0.6) as u8]
        } else {
            [250, 250, 250, (color[3] as f32 * 0.6) as u8]
        };
        draw_text_rgba_core(
            buf,
            w,
            h,
            text,
            start_x + shadow_offset,
            start_y + shadow_offset,
            font_size_px,
            shadow_color,
        );
    }

    draw_text_rgba_core(buf, w, h, text, start_x, start_y, font_size_px, color);
}

#[allow(clippy::too_many_arguments)]
fn draw_text_rgba_core(
    buf: &mut [u8],
    w: u32,
    h: u32,
    text: &str,
    start_x: f32,
    start_y: f32,
    font_size_px: f32,
    color: [u8; 4],
) {
    let scale = font_size_px / 100.0;
    let stroke_radius = (font_size_px * 0.045).max(0.7);
    let mut cursor_x = start_x;
    let base_alpha = color[3] as f32 / 255.0;

    for c in text.chars() {
        let (advance, strokes) = glyph_definition(c);
        let is_lower = c.is_ascii_lowercase();
        let char_scale = if is_lower { scale * 0.85 } else { scale };
        let y_offset = if is_lower { font_size_px * 0.15 } else { 0.0 };

        for &(sx1, sy1, sx2, sy2) in strokes {
            let x1 = cursor_x + sx1 * char_scale;
            let y1 = start_y + y_offset + sy1 * char_scale;
            let x2 = cursor_x + sx2 * char_scale;
            let y2 = start_y + y_offset + sy2 * char_scale;

            let min_x = (x1.min(x2) - stroke_radius - 1.5).floor().max(0.0) as u32;
            let max_x = (x1.max(x2) + stroke_radius + 1.5)
                .ceil()
                .min(w as f32 - 1.0) as u32;
            let min_y = (y1.min(y2) - stroke_radius - 1.5).floor().max(0.0) as u32;
            let max_y = (y1.max(y2) + stroke_radius + 1.5)
                .ceil()
                .min(h as f32 - 1.0) as u32;

            for py in min_y..=max_y {
                for px in min_x..=max_x {
                    let d = dist_to_segment(px as f32 + 0.5, py as f32 + 0.5, x1, y1, x2, y2);
                    if d < stroke_radius + 1.0 {
                        let coverage = ((stroke_radius + 1.0 - d) / 1.0).clamp(0.0, 1.0);
                        let a = coverage * base_alpha;
                        if a > 0.001 {
                            let idx = ((py * w + px) * 4) as usize;
                            let inv_a = 1.0 - a;
                            buf[idx] =
                                (color[0] as f32 * a + buf[idx] as f32 * inv_a).round() as u8;
                            buf[idx + 1] =
                                (color[1] as f32 * a + buf[idx + 1] as f32 * inv_a).round() as u8;
                            buf[idx + 2] =
                                (color[2] as f32 * a + buf[idx + 2] as f32 * inv_a).round() as u8;
                        }
                    }
                }
            }
        }
        cursor_x += advance * scale + (font_size_px * 0.05);
    }
}

// ---------------------------------------------------------------------------
// Pure Rust PNG Decoder using miniz_oxide
// ---------------------------------------------------------------------------

/// Decodes standard RGBA/RGB PNG bytes into (rgba_pixels, width, height).
pub fn decode_png_rgba(bytes: &[u8]) -> Result<(Vec<u8>, u32, u32), String> {
    const PNG_HEADER: [u8; 8] = [137, 80, 78, 71, 13, 10, 26, 10];
    if bytes.len() < 8 || bytes[..8] != PNG_HEADER {
        return Err("Invalid PNG signature".to_string());
    }

    let mut pos = 8;
    let mut width = 0u32;
    let mut height = 0u32;
    let mut bit_depth = 8u8;
    let mut color_type = 6u8; // 6 = RGBA, 2 = RGB
    let mut idat_data = Vec::new();

    while pos + 8 <= bytes.len() {
        let chunk_len = u32::from_be_bytes(bytes[pos..pos + 4].try_into().unwrap()) as usize;
        let chunk_type = &bytes[pos + 4..pos + 8];
        let chunk_data_start = pos + 8;
        let chunk_data_end = chunk_data_start + chunk_len;
        if chunk_data_end + 4 > bytes.len() {
            break;
        }

        match chunk_type {
            b"IHDR" => {
                if chunk_len >= 13 {
                    width = u32::from_be_bytes(
                        bytes[chunk_data_start..chunk_data_start + 4]
                            .try_into()
                            .unwrap(),
                    );
                    height = u32::from_be_bytes(
                        bytes[chunk_data_start + 4..chunk_data_start + 8]
                            .try_into()
                            .unwrap(),
                    );
                    bit_depth = bytes[chunk_data_start + 8];
                    color_type = bytes[chunk_data_start + 9];
                }
            }
            b"IDAT" => {
                idat_data.extend_from_slice(&bytes[chunk_data_start..chunk_data_end]);
            }
            b"IEND" => break,
            _ => {}
        }
        pos = chunk_data_end + 4; // skip CRC
    }

    if width == 0 || height == 0 {
        return Err("Invalid PNG dimensions in IHDR".to_string());
    }
    if bit_depth != 8 {
        return Err(format!("Unsupported PNG bit depth: {bit_depth}"));
    }

    let bytes_per_pixel = match color_type {
        6 => 4, // RGBA
        2 => 3, // RGB
        _ => return Err(format!("Unsupported PNG color type: {color_type}")),
    };

    // Decompress IDAT stream with miniz_oxide
    let decompressed = miniz_oxide::inflate::decompress_to_vec_zlib(&idat_data)
        .map_err(|e| format!("PNG zlib decompression failed: {e:?}"))?;

    let stride = width as usize * bytes_per_pixel;
    let expected_len = (stride + 1) * height as usize;
    if decompressed.len() < expected_len {
        return Err(format!(
            "Decompressed PNG data truncated: {} < {}",
            decompressed.len(),
            expected_len
        ));
    }

    // Unfilter scanlines
    let mut raw_scanlines = vec![0u8; width as usize * height as usize * bytes_per_pixel];
    let mut in_pos = 0;
    for y in 0..height as usize {
        let filter = decompressed[in_pos];
        in_pos += 1;
        let line_in = &decompressed[in_pos..in_pos + stride];
        in_pos += stride;

        let out_start = y * stride;
        let bpp = bytes_per_pixel;

        match filter {
            0 => {
                // None
                raw_scanlines[out_start..out_start + stride].copy_from_slice(line_in);
            }
            1 => {
                // Sub
                for x in 0..stride {
                    let left = if x >= bpp {
                        raw_scanlines[out_start + x - bpp]
                    } else {
                        0
                    };
                    raw_scanlines[out_start + x] = line_in[x].wrapping_add(left);
                }
            }
            2 => {
                // Up
                for x in 0..stride {
                    let up = if y > 0 {
                        raw_scanlines[(y - 1) * stride + x]
                    } else {
                        0
                    };
                    raw_scanlines[out_start + x] = line_in[x].wrapping_add(up);
                }
            }
            3 => {
                // Average
                for x in 0..stride {
                    let left = if x >= bpp {
                        raw_scanlines[out_start + x - bpp] as u16
                    } else {
                        0
                    };
                    let up = if y > 0 {
                        raw_scanlines[(y - 1) * stride + x] as u16
                    } else {
                        0
                    };
                    let avg = ((left + up) / 2) as u8;
                    raw_scanlines[out_start + x] = line_in[x].wrapping_add(avg);
                }
            }
            4 => {
                // Paeth
                for x in 0..stride {
                    let a = if x >= bpp {
                        raw_scanlines[out_start + x - bpp] as i16
                    } else {
                        0
                    };
                    let b = if y > 0 {
                        raw_scanlines[(y - 1) * stride + x] as i16
                    } else {
                        0
                    };
                    let c = if x >= bpp && y > 0 {
                        raw_scanlines[(y - 1) * stride + x - bpp] as i16
                    } else {
                        0
                    };
                    let p = a + b - c;
                    let pa = (p - a).abs();
                    let pb = (p - b).abs();
                    let pc = (p - c).abs();
                    let pr = if pa <= pb && pa <= pc {
                        a
                    } else if pb <= pc {
                        b
                    } else {
                        c
                    };
                    raw_scanlines[out_start + x] = line_in[x].wrapping_add(pr as u8);
                }
            }
            _ => return Err(format!("Unknown PNG filter type: {filter}")),
        }
    }

    // Convert to RGBA
    let mut rgba_out = vec![0u8; width as usize * height as usize * 4];
    if color_type == 6 {
        rgba_out.copy_from_slice(&raw_scanlines);
    } else {
        // RGB -> RGBA
        for i in 0..(width as usize * height as usize) {
            rgba_out[i * 4] = raw_scanlines[i * 3];
            rgba_out[i * 4 + 1] = raw_scanlines[i * 3 + 1];
            rgba_out[i * 4 + 2] = raw_scanlines[i * 3 + 2];
            rgba_out[i * 4 + 3] = 255;
        }
    }

    Ok((rgba_out, width, height))
}

// ---------------------------------------------------------------------------
// Museum Frame (EXIF Gallery Print Mat)
// ---------------------------------------------------------------------------

/// Expands canvas and renders museum gallery margins with camera EXIF typography.
pub fn apply_museum_frame(
    src: &[u8],
    w: u32,
    h: u32,
    theme: MuseumFrameTheme,
    line1: &str,
    line2: &str,
) -> (Vec<u8>, u32, u32) {
    let side_margin = ((w as f32 * 0.045).round() as u32).max(16);
    let top_margin = side_margin;
    let bottom_margin = ((w as f32 * 0.125).round() as u32).max(48);

    let new_w = w + side_margin * 2;
    let new_h = h + top_margin + bottom_margin;

    let bg = theme.bg_rgba();
    let text_primary = theme.text_primary_rgba();
    let text_secondary = theme.text_secondary_rgba();

    // Fill entire canvas with theme background
    let mut out = Vec::with_capacity((new_w * new_h * 4) as usize);
    for _ in 0..(new_w * new_h) {
        out.extend_from_slice(&bg);
    }

    // Copy original image into center-top
    for y in 0..h {
        let src_row_start = ((y * w) * 4) as usize;
        let dst_row_start = (((y + top_margin) * new_w + side_margin) * 4) as usize;
        out[dst_row_start..dst_row_start + (w * 4) as usize]
            .copy_from_slice(&src[src_row_start..src_row_start + (w * 4) as usize]);
    }

    // Compute typography sizes
    let font_size_primary = ((bottom_margin as f32 * 0.22).round()).clamp(12.0, 72.0);
    let font_size_secondary = font_size_primary * 0.82;

    let text_y_primary = (h + top_margin) as f32 + bottom_margin as f32 * 0.32;
    let text_y_secondary = text_y_primary + font_size_primary * 1.35;

    // Draw Line 1 (Camera & Lens) - left aligned with photo
    if !line1.is_empty() {
        draw_text_rgba(
            &mut out,
            new_w,
            new_h,
            line1,
            side_margin as f32,
            text_y_primary,
            font_size_primary,
            text_primary,
            false,
        );
    }

    // Draw Line 2 (Exposure details) - right aligned or second row
    if !line2.is_empty() {
        let (meas_w, _) = measure_text(line2, font_size_primary);
        let target_x = ((new_w - side_margin) as f32 - meas_w).max(side_margin as f32);
        if target_x > side_margin as f32 + 20.0 {
            // Fits side-by-side on same baseline as primary line!
            draw_text_rgba(
                &mut out,
                new_w,
                new_h,
                line2,
                target_x,
                text_y_primary,
                font_size_primary,
                text_secondary,
                false,
            );
        } else {
            // Stack on second row
            draw_text_rgba(
                &mut out,
                new_w,
                new_h,
                line2,
                side_margin as f32,
                text_y_secondary,
                font_size_secondary,
                text_secondary,
                false,
            );
        }
    }

    (out, new_w, new_h)
}

// ---------------------------------------------------------------------------
// Custom Photographer Signature (Text & Logo)
// ---------------------------------------------------------------------------

/// Computes (x, y) coordinates for a given anchor within bounding dimensions.
pub fn calculate_anchor_position(
    canvas_w: u32,
    canvas_h: u32,
    item_w: f32,
    item_h: f32,
    anchor: WatermarkAnchor,
    margin_x: f32,
    margin_y: f32,
) -> (f32, f32) {
    let (x, y) = match anchor {
        WatermarkAnchor::TopLeft => (margin_x, margin_y),
        WatermarkAnchor::TopCenter => ((canvas_w as f32 - item_w) / 2.0, margin_y),
        WatermarkAnchor::TopRight => (canvas_w as f32 - item_w - margin_x, margin_y),
        WatermarkAnchor::CenterLeft => (margin_x, (canvas_h as f32 - item_h) / 2.0),
        WatermarkAnchor::Center => (
            (canvas_w as f32 - item_w) / 2.0,
            (canvas_h as f32 - item_h) / 2.0,
        ),
        WatermarkAnchor::CenterRight => (
            canvas_w as f32 - item_w - margin_x,
            (canvas_h as f32 - item_h) / 2.0,
        ),
        WatermarkAnchor::BottomLeft => (margin_x, canvas_h as f32 - item_h - margin_y),
        WatermarkAnchor::BottomCenter => (
            (canvas_w as f32 - item_w) / 2.0,
            canvas_h as f32 - item_h - margin_y,
        ),
        WatermarkAnchor::BottomRight => (
            canvas_w as f32 - item_w - margin_x,
            canvas_h as f32 - item_h - margin_y,
        ),
    };
    (x.max(0.0), y.max(0.0))
}

/// Applies custom photographer text signature with 9-point grid alignment.
pub fn apply_text_signature(
    buf: &mut [u8],
    w: u32,
    h: u32,
    text: &str,
    anchor: WatermarkAnchor,
    opacity: f32,
    size_pct: f32,
) {
    if text.is_empty() || opacity <= 0.0 {
        return;
    }
    let font_size = ((w.min(h) as f32) * (size_pct / 100.0)).clamp(12.0, 160.0);
    let (text_w, text_h) = measure_text(text, font_size);
    let margin = (w.min(h) as f32 * 0.03).max(12.0);

    let (pos_x, pos_y) = calculate_anchor_position(w, h, text_w, text_h, anchor, margin, margin);

    let alpha = (opacity.clamp(0.0, 1.0) * 255.0).round() as u8;
    let color = [255, 255, 255, alpha];

    draw_text_rgba(buf, w, h, text, pos_x, pos_y, font_size, color, true);
}

/// Bilinear sampling helper for resizing images.
fn sample_bilinear(src: &[u8], sw: u32, sh: u32, u: f32, v: f32) -> [u8; 4] {
    let x = (u * sw as f32 - 0.5).clamp(0.0, sw as f32 - 1.0);
    let y = (v * sh as f32 - 0.5).clamp(0.0, sh as f32 - 1.0);

    let x0 = x.floor() as u32;
    let y0 = y.floor() as u32;
    let x1 = (x0 + 1).min(sw - 1);
    let y1 = (y0 + 1).min(sh - 1);

    let fx = x - x0 as f32;
    let fy = y - y0 as f32;

    let p00 = ((y0 * sw + x0) * 4) as usize;
    let p10 = ((y0 * sw + x1) * 4) as usize;
    let p01 = ((y1 * sw + x0) * 4) as usize;
    let p11 = ((y1 * sw + x1) * 4) as usize;

    let mut out = [0u8; 4];
    for c in 0..4 {
        let top = src[p00 + c] as f32 * (1.0 - fx) + src[p10 + c] as f32 * fx;
        let bot = src[p01 + c] as f32 * (1.0 - fx) + src[p11 + c] as f32 * fx;
        out[c] = (top * (1.0 - fy) + bot * fy).round().clamp(0.0, 255.0) as u8;
    }
    out
}

/// Applies custom transparent PNG logo with bilinear scaling and alpha blending.
#[allow(clippy::too_many_arguments)]
pub fn apply_logo_watermark(
    buf: &mut [u8],
    w: u32,
    h: u32,
    logo_rgba: &[u8],
    logo_w: u32,
    logo_h: u32,
    anchor: WatermarkAnchor,
    opacity: f32,
    scale_pct: f32,
) {
    if logo_w == 0 || logo_h == 0 || opacity <= 0.0 {
        return;
    }

    let target_w = ((w as f32 * (scale_pct / 100.0)).round() as u32).max(16);
    let target_h = (((target_w as f32 / logo_w as f32) * logo_h as f32).round() as u32).max(16);
    let margin = (w.min(h) as f32 * 0.03).max(12.0);

    let (pos_x, pos_y) = calculate_anchor_position(
        w,
        h,
        target_w as f32,
        target_h as f32,
        anchor,
        margin,
        margin,
    );

    let px_start = pos_x.floor() as u32;
    let py_start = pos_y.floor() as u32;
    let user_alpha = opacity.clamp(0.0, 1.0);

    for dy in 0..target_h {
        let py = py_start + dy;
        if py >= h {
            break;
        }
        let v = (dy as f32 + 0.5) / target_h as f32;

        for dx in 0..target_w {
            let px = px_start + dx;
            if px >= w {
                break;
            }
            let u = (dx as f32 + 0.5) / target_w as f32;
            let sample = sample_bilinear(logo_rgba, logo_w, logo_h, u, v);

            let a = (sample[3] as f32 / 255.0) * user_alpha;
            if a > 0.001 {
                let idx = ((py * w + px) * 4) as usize;
                let inv_a = 1.0 - a;
                buf[idx] = (sample[0] as f32 * a + buf[idx] as f32 * inv_a).round() as u8;
                buf[idx + 1] = (sample[1] as f32 * a + buf[idx + 1] as f32 * inv_a).round() as u8;
                buf[idx + 2] = (sample[2] as f32 * a + buf[idx + 2] as f32 * inv_a).round() as u8;
            }
        }
    }
}

/// Applies the voluntary "⬡ Edited in ApertureX | 100% Offline" FOSS badge.
pub fn apply_foss_badge(buf: &mut [u8], w: u32, h: u32) {
    let font_size = ((w.min(h) as f32 * 0.018).round()).clamp(10.0, 36.0);
    let text = "⬡ EDITED IN APERTUREX | 100% OFFLINE";
    let (text_w, text_h) = measure_text(text, font_size);
    let margin = (w.min(h) as f32 * 0.025).max(10.0);

    let (pos_x, pos_y) = calculate_anchor_position(
        w,
        h,
        text_w,
        text_h,
        WatermarkAnchor::BottomRight,
        margin,
        margin,
    );

    let color = [255, 255, 255, 115]; // ~45% opacity
    draw_text_rgba(buf, w, h, text, pos_x, pos_y, font_size, color, true);
}

/// Executes all active branding and watermarking transformations on the final export buffer.
pub fn process_branding_pipeline(
    src_rgba: &[u8],
    w: u32,
    h: u32,
    spec: &WatermarkSpec,
) -> (Vec<u8>, u32, u32) {
    let (mut out, out_w, out_h) = if spec.enable_museum_frame {
        apply_museum_frame(
            src_rgba,
            w,
            h,
            spec.frame_theme,
            &spec.exif_line1,
            &spec.exif_line2,
        )
    } else {
        (src_rgba.to_vec(), w, h)
    };

    if spec.enable_signature && !spec.signature_text.is_empty() {
        apply_text_signature(
            &mut out,
            out_w,
            out_h,
            &spec.signature_text,
            spec.signature_anchor,
            spec.signature_opacity,
            spec.signature_size_pct,
        );
    }

    if spec.enable_logo && !spec.logo_bytes.is_empty() {
        if let Ok((logo_rgba, lw, lh)) = decode_png_rgba(&spec.logo_bytes) {
            apply_logo_watermark(
                &mut out,
                out_w,
                out_h,
                &logo_rgba,
                lw,
                lh,
                spec.logo_anchor,
                spec.logo_opacity,
                spec.logo_scale_pct,
            );
        }
    }

    if spec.enable_foss_badge {
        apply_foss_badge(&mut out, out_w, out_h);
    }

    (out, out_w, out_h)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_text_measurement_and_rendering() {
        let (w, h) = measure_text("SONY A7III • 35MM", 24.0);
        assert!(w > 100.0, "Measured width should reflect characters: {w}");
        assert_eq!(h, 24.0);

        let mut buf = vec![0u8; 400 * 100 * 4];
        draw_text_rgba(
            &mut buf,
            400,
            100,
            "APERTUREX",
            20.0,
            20.0,
            30.0,
            [255, 255, 255, 255],
            false,
        );

        // Verify non-zero alpha pixels were drawn
        let drawn_pixels = buf.chunks(4).filter(|px| px[0] > 0).count();
        assert!(drawn_pixels > 100, "Text should render pixels into buffer");
    }

    #[test]
    fn test_museum_frame_expansion() {
        let src = vec![128u8; 200 * 100 * 4];
        let (out, out_w, out_h) = apply_museum_frame(
            &src,
            200,
            100,
            MuseumFrameTheme::StudioWhite,
            "LEICA M11 • SUMMILUX 35MM",
            "1/500s • f/1.4 • ISO 64",
        );

        assert!(out_w > 200, "Frame must expand width: {out_w}");
        assert!(out_h > 100, "Frame must expand height: {out_h}");
        assert_eq!(out.len(), (out_w * out_h * 4) as usize);

        // Top left corner should be Studio White (255, 255, 255)
        assert_eq!(&out[0..4], &[255, 255, 255, 255]);
    }

    #[test]
    fn test_foss_badge_application() {
        let mut buf = vec![50u8; 300 * 200 * 4];
        apply_foss_badge(&mut buf, 300, 200);

        // Badge is placed in bottom right corner; verify pixels modified
        let modified = buf.chunks(4).filter(|px| px[0] > 50).count();
        assert!(modified > 20, "FOSS badge should modify buffer pixels");
    }

    #[test]
    fn test_png_decoder_roundtrip() {
        // Construct a minimal 2x2 RGBA PNG
        // Header
        let mut png = vec![137, 80, 78, 71, 13, 10, 26, 10];

        // IHDR chunk: 2x2, 8-bit depth, color type 6 (RGBA)
        let mut ihdr_data = Vec::new();
        ihdr_data.extend_from_slice(&2u32.to_be_bytes()); // width = 2
        ihdr_data.extend_from_slice(&2u32.to_be_bytes()); // height = 2
        ihdr_data.push(8); // bit depth
        ihdr_data.push(6); // RGBA
        ihdr_data.push(0); // compression
        ihdr_data.push(0); // filter
        ihdr_data.push(0); // interlace

        png.extend_from_slice(&(ihdr_data.len() as u32).to_be_bytes());
        png.extend_from_slice(b"IHDR");
        png.extend_from_slice(&ihdr_data);
        png.extend_from_slice(&[0, 0, 0, 0]); // dummy CRC

        // Scanlines: 2 rows of 2 pixels (8 bytes + 1 filter byte each = 9 bytes/row)
        let mut raw_data = Vec::new();
        for _ in 0..2 {
            raw_data.push(0); // filter: None
            raw_data.extend_from_slice(&[255, 0, 0, 255, 0, 255, 0, 255]);
        }

        let compressed = miniz_oxide::deflate::compress_to_vec_zlib(&raw_data, 6);
        png.extend_from_slice(&(compressed.len() as u32).to_be_bytes());
        png.extend_from_slice(b"IDAT");
        png.extend_from_slice(&compressed);
        png.extend_from_slice(&[0, 0, 0, 0]); // dummy CRC

        // IEND chunk
        png.extend_from_slice(&0u32.to_be_bytes());
        png.extend_from_slice(b"IEND");
        png.extend_from_slice(&[0, 0, 0, 0]);

        let (decoded, w, h) = decode_png_rgba(&png).unwrap();
        assert_eq!(w, 2);
        assert_eq!(h, 2);
        assert_eq!(decoded.len(), 16);
        assert_eq!(&decoded[0..4], &[255, 0, 0, 255]); // red
        assert_eq!(&decoded[4..8], &[0, 255, 0, 255]); // green
    }
}
