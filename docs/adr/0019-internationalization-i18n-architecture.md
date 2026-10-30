# ADR 0019 — Internationalization (i18n) Architecture

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0004 (GPL-3 & F-Droid Distribution), ADR 0006 (UI Material 3)

---

## 1. Context

ApertureX is distributed globally as a FOSS photo editor across Android, iOS, and desktop platforms. Previously, UI strings were hardcoded in English throughout widgets, parameter catalogs, dialogs, and accessibility labels. To support global adoption:
- The app requires native localization across major languages without external cloud lookup or proprietary runtime translation services.
- The localization system must integrate with Flutter's standard `MaterialApp.localizationsDelegates` and `supportedLocales`.
- Performance overhead must be zero: string lookup must be instantaneous ($O(1)$) and avoid excessive code-generation rebuild friction during rapid prototyping.

## 2. Decision

Adopt `flutter_localizations` (from the Flutter SDK) paired with `package:intl`, implementing a centralized, strongly-typed dictionary provider in `AppStrings` (`app/lib/l10n/app_strings.dart`):

1. **Multi-Locale Core Support**:
   - Initial tier supporting 6 major global languages:
     - English (`en`) — Default / Fallback
     - Spanish (`es`)
     - German (`de`)
     - French (`fr`)
     - Japanese (`ja`)
     - Chinese (`zh`)

2. **Hierarchical Dictionary Structure**:
   - General UI & Navigation (`appName`, `cancel`, `apply`, `delete`, `reset`, `undo`, `redo`, `export`)
   - Lightroom Master Tabs (`light`, `color`, `effects`, `detail`, `optics`, `geometry`, `presets`)
   - Tooltips, A/B Comparison, and Soft Proofing options
   - Screen Reader Semantics hints and status announcements

3. **Fallback & Delegation**:
   - Implement `AppStringsDelegate extends LocalizationsDelegate<AppStrings>` with automatic language matching and graceful fallback to English when unsupported locales or missing keys are encountered.
   - Register alongside `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, and `GlobalCupertinoLocalizations` in `main.dart`.

## 3. Consequences

### Positive
- **Global Accessibility**: Users across Europe, the Americas, and Asia experience a native, localized darkroom environment.
- **Fast & Deterministic**: Pure Dart in-memory dictionary lookup without async file I/O or bundle loading delays.
- **Strict F-Droid Compliance**: Zero network activity required; works 100% offline.

### Negative
- As new editing tools are added, string definitions must be mirrored across all 6 locale dictionaries in `AppStrings`.
