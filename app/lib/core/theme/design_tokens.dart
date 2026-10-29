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

  static const Duration fast = Durations.short3;
  static const Duration medium = Durations.medium2;
  static const Duration slow = Durations.medium4;

  static const Curve standard = Easing.standard;
  static const Curve emphasized = Easing.emphasizedDecelerate;
}

/// Centralized Material 3 motion constants for ApertureX (ADR 0011).
///
/// All animation durations and curves derive from Flutter's built-in
/// `Durations` and `Easing` classes, which align with the Material 3 motion
/// specification. Never hardcode `Duration(milliseconds: ...)` or `Curves.*`
/// for new animation code.
abstract class AppMotion {
  const AppMotion._();

  // --- Standard transitions ------------------------------------------------

  static const Duration standardDuration = Durations.medium2;
  static const Curve standardCurve = Easing.standard;

  // --- Page transitions ----------------------------------------------------

  static const Duration pageDuration = Durations.medium4;
  static const Curve pageEnterCurve = Easing.emphasizedDecelerate;
  static const Curve pageExitCurve = Easing.emphasizedAccelerate;

  // --- Fades ---------------------------------------------------------------

  static const Duration fadeDuration = Durations.short3;
  static const Curve fadeCurve = Easing.standard;

  // --- Scrub / gesture HUD ------------------------------------------------

  static const Duration scrubDuration = Durations.short2;
  static const Curve scrubCurve = Easing.standard;

  // --- Micro fades --------------------------------------------------------

  static const Duration microDuration = Durations.short1;
  static const Duration shortDuration = Durations.short2;

  // --- Sheet / panel ------------------------------------------------------

  static const Duration sheetDuration = Durations.medium2;
  static const Curve sheetCurve = Easing.standard;
}
