/// Material 3 window size classes as the shared breakpoint vocabulary.
///
/// Branch on width, never on device or platform. A phone in a foldable's front
/// display, a resized desktop window, and a tablet in split-screen all defeat
/// `Platform.isX` checks — but they all report their real constraints.
enum WindowSizeClass {
  compact,
  medium,
  expanded,
  large,
  extraLarge,
}

/// Maps a logical-pixel width to a [WindowSizeClass] using the Material 3
/// structural breakpoints:
///
/// - compact:    < 600
/// - medium:     600–839
/// - expanded:   840–1199
/// - large:      1200–1599
/// - extraLarge: >= 1600
WindowSizeClass windowSizeClassFor(double width) => switch (width) {
      < 600 => WindowSizeClass.compact,
      < 840 => WindowSizeClass.medium,
      < 1200 => WindowSizeClass.expanded,
      < 1600 => WindowSizeClass.large,
      _ => WindowSizeClass.extraLarge,
    };
