import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../settings/onboarding.dart';
import '../../settings/shell_preference.dart';

/// Interactive onboarding tour presenting ApertureX pro editing features,
/// dual UI shells, offline AI neural forge, and shell preferences.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.isModal = false});

  final bool isModal;

  /// Presents the onboarding screen modally.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => const OnboardingScreen(isModal: true),
    );
  }

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(hasCompletedOnboardingProvider.notifier).complete();
    if (widget.isModal) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentShell = ref.watch(shellPreferenceProvider);

    final pages = [
      const _OnboardingSlide(
        icon: Icons.camera_outlined,
        badge: 'PROFESSIONAL FOSS SUITE',
        title: 'Welcome to ApertureX',
        subtitle:
            'A mobile-native pro photo studio powered by Flutter and an ultra-fast Rust engine via zero-copy GPU textures.',
        highlights: [
          'Non-destructive editing with infinite undo & branch history',
          'Linear photometric color grading and 65×65×65 3D LUTs',
          '100% offline, zero telemetry, full privacy compliance',
        ],
      ),
      const _OnboardingSlide(
        icon: Icons.tune,
        badge: 'DUAL INTERFACE SHELLS',
        title: 'Two Shells, One Shared Recipe',
        subtitle:
            'Switch anytime between deep Lightroom-style precision panels and Snapseed-style on-canvas gesture HUD.',
        highlights: [
          'Panels: Parametric tone curves, HSL mixer wheels, and Detail tools',
          'Gestures: Swipe up/down to pick tool, swipe left/right to adjust',
          'Seamless interoperability: Both shells share the exact same recipe',
        ],
      ),
      const _OnboardingSlide(
        icon: Icons.auto_awesome,
        badge: 'LOCAL AI & PRO WORKFLOW',
        title: 'Neural Forge & Pro Diagnostics',
        subtitle:
            'State-of-the-art on-device AI tools and cinema-grade exposure assist built directly into the viewport.',
        highlights: [
          'AI Neural Denoise & one-tap Subject, Sky, and Face masking',
          'Instant 120 FPS Wiper and Split Before/After (Y) comparisons',
          'ARRI 16-Zone False Color Heatmaps and ICC Soft Proofing',
        ],
      ),
      _OnboardingSlide(
        icon: Icons.check_circle_outline,
        badge: 'PERSONALIZE YOUR STUDIO',
        title: 'Choose Your Editing Style',
        subtitle:
            'Select your preferred default interface. You can change this at any time in App Settings.',
        customContent: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          child: SegmentedButton<AppShellKind>(
            segments: const [
              ButtonSegment(
                value: AppShellKind.lightroom,
                icon: Icon(Icons.tune),
                label: Text('Precision Panels'),
              ),
              ButtonSegment(
                value: AppShellKind.snapseed,
                icon: Icon(Icons.gesture),
                label: Text('Gesture HUD'),
              ),
            ],
            selected: {currentShell},
            onSelectionChanged: (selected) {
              ref.read(shellPreferenceProvider.notifier).select(selected.first);
            },
          ),
        ),
        highlights: const [
          'Tip: On tablets and desktops, ApertureX adopts an adaptive split layout.',
          'Full native stylus support with pressure sensitivity and palm rejection.',
        ],
      ),
    ];

    final isLastPage = _currentPage == pages.length - 1;

    final body = SafeArea(
      child: Column(
        children: [
          // Header / Skip button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.lens_blur,
                        size: 18,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: Insets.xs + 2),
                    Text(
                      'ApertureX Studio',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    isLastPage ? 'Close' : 'Skip',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Slides PageView
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) => pages[i],
            ),
          ),

          // Navigation and Dots
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Dots indicator
                Row(
                  children: List.generate(
                    pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: _currentPage == i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                // Back / Next buttons
                Row(
                  children: [
                    if (_currentPage > 0) ...[
                      OutlinedButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: Insets.sm),
                    ],
                    FilledButton(
                      key: const Key('onboarding-action-button'),
                      onPressed: () {
                        if (isLastPage) {
                          _finish();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(isLastPage ? 'Get Started' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isModal) {
      final size = MediaQuery.of(context).size;
      return Container(
        height: size.height * 0.88,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: body,
      );
    }

    return Scaffold(body: body);
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.highlights,
    this.customContent,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  final List<String> highlights;
  final Widget? customContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: Insets.sm),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer,
                  scheme.primaryContainer.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: Insets.md),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: Insets.xs),

          // Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: Insets.lg),

          ?customContent,

          // Feature highlights card
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                for (final item in highlights) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            item,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
