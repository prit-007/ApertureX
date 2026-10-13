import 'package:material_ui/material_ui.dart';

/// Shared spacing, shape and motion tokens for ApertureX (ADR 0011).
///
/// Widgets reference these instead of magic numbers so the whole app stays on a
/// consistent grid and rhythm — the difference between a demo and a product.
class Insets {
  const Insets._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard inset for a bottom-sheet body.
  static const EdgeInsets sheet = EdgeInsets.fromLTRB(lg, sm, lg, lg);

  /// Standard inset for a screen body.
  static const EdgeInsets screen = EdgeInsets.all(lg);
}

class Radii {
  const Radii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(
    Radius.circular(pill),
  );
}

class Motion {
  const Motion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}
