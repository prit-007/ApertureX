import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/tool_definition.dart';
import '../../features/presets/community_preset_model.dart';
import '../../features/presets/community_presets_provider.dart';
import '../../features/presets/preset_card_dialog.dart';
import '../../features/presets/qr_scanner_sheet.dart';
import 'app_sheet.dart';
import 'paste_button.dart';

/// The look gallery: apply a built-in look, scan a Look QR, or discover
/// community-contributed presets from the ApertureX Community Hub.
class LooksSheet extends ConsumerStatefulWidget {
  const LooksSheet({super.key});

  @override
  ConsumerState<LooksSheet> createState() => _LooksSheetState();
}

class _LooksSheetState extends ConsumerState<LooksSheet> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  String? _importError;
  int _selectedTab = 0; // 0: My Looks & QR, 1: Community Hub

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _apply(ToolDefinition tool) {
    ref.read(recipeControllerProvider.notifier).applyTool(tool);
    ref.read(recipeControllerProvider.notifier).commit(label: tool.name);
    axLog(LogDomain.preset, 'Applied look "${tool.name}"');
    Navigator.of(context).maybePop();
  }

  void _import() {
    try {
      final tool = ToolDefinition.decode(_controller.text);
      setState(() => _importError = null);
      _apply(tool);
    } on FormatException catch (e) {
      setState(() => _importError = e.message);
    }
  }

  ToolDefinition _currentRecipeAsTool(EditRecipe recipe) {
    final params = <String, double>{};
    for (final p in Parameter.values) {
      final v = valueOf(recipe, p);
      final neutral = specOf(p).neutral;
      if ((v - neutral).abs() > 1e-4) {
        params[p.name] = v;
      }
    }
    return ToolDefinition(
      name: 'Custom Look',
      description: 'Custom color grade from ApertureX',
      params: params.isEmpty ? {'contrast': 0.0} : params,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final communityState = ref.watch(communityPresetsProvider);
    final communityNotifier = ref.read(communityPresetsProvider.notifier);

    return AppSheet(
      title: 'Looks & Presets',
      subtitle: _selectedTab == 0
          ? 'One-tap grades, Pat David film emulations, or scan a shared Look QR.'
          : 'Discover open-source community color grades, film recipes & looks.',
      children: [
        Center(
          child: SegmentedButton<int>(
            key: const Key('looks-tab-segmented-button'),
            segments: const [
              ButtonSegment<int>(
                value: 0,
                label: Text('My Looks & QR'),
                icon: Icon(Icons.palette_outlined, size: 16),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Community Hub'),
                icon: Icon(Icons.explore_outlined, size: 16),
              ),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (set) => setState(() => _selectedTab = set.first),
          ),
        ),
        const SizedBox(height: Insets.md),
        if (_selectedTab == 0) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('scan-qr-look-button'),
                  onPressed: () => showAppSheet(context, const QrScannerSheet()),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan QR Look'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('share-current-edit-qr-button'),
                  onPressed: () {
                    final recipe = ref.read(recipeControllerProvider).recipe;
                    final tool = _currentRecipeAsTool(recipe);
                    showPresetCardDialog(context, tool: tool);
                  },
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('Share Edit as QR'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          for (final tool in ToolLibrary.builtins)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_fix_high),
              title: Text(tool.name),
              subtitle: Text(tool.description),
              trailing: IconButton(
                key: Key('share-look-qr-${tool.name}'),
                icon: const Icon(Icons.qr_code, size: 20),
                tooltip: 'Share as QR Card',
                onPressed: () => showPresetCardDialog(context, tool: tool),
              ),
              onTap: () => _apply(tool),
            ),
          const SizedBox(height: Insets.lg),
          TextField(
            controller: _controller,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Paste a shared look (JSON or apx:// URI)…',
              errorText: _importError,
              suffixIcon: PasteButton(controller: _controller),
            ),
          ),
          const SizedBox(height: Insets.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _import,
              child: const Text('Import look'),
            ),
          ),
        ] else ...[
          // ─── Community Hub Tab ──────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in ['All', 'Film', 'Portraits', 'Moody', 'Landscape'])
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.xs),
                    child: FilterChip(
                      key: Key('filter-category-$cat'),
                      label: Text(cat),
                      selected: communityState.selectedCategory.toLowerCase() == cat.toLowerCase(),
                      onSelected: (_) => communityNotifier.selectCategory(cat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search community looks...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        communityNotifier.setSearchQuery('');
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) {
              communityNotifier.setSearchQuery(val);
              setState(() {});
            },
          ),
          const SizedBox(height: Insets.md),
          if (communityState.filteredPresets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.xl),
              child: Center(
                child: Text(
                  'No community looks found.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final preset in communityState.filteredPresets)
              _CommunityPresetCard(
                preset: preset,
                isInstalled: communityNotifier.isInstalled(preset.id),
                isDownloading: communityState.downloadingIds.contains(preset.id),
                onApply: () => _apply(preset.toToolDefinition()),
                onDownload: () => communityNotifier.downloadPreset(preset),
                onShareQr: () => showPresetCardDialog(context, tool: preset.toToolDefinition()),
              ),
        ],
      ],
    );
  }
}

class _CommunityPresetCard extends StatelessWidget {
  const _CommunityPresetCard({
    required this.preset,
    required this.isInstalled,
    required this.isDownloading,
    required this.onApply,
    required this.onDownload,
    required this.onShareQr,
  });

  final CommunityPreset preset;
  final bool isInstalled;
  final bool isDownloading;
  final VoidCallback onApply;
  final VoidCallback onDownload;
  final VoidCallback onShareQr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.outlined(
      key: Key('community-card-${preset.id}'),
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    preset.category.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Text(
                  preset.author,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  preset.rating.toStringAsFixed(1),
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: Insets.xs),
                IconButton(
                  key: Key('share-community-qr-${preset.id}'),
                  icon: const Icon(Icons.qr_code, size: 18),
                  tooltip: 'Share Look QR Card',
                  onPressed: onShareQr,
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              preset.name,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              preset.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isDownloading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isInstalled)
                  FilledButton.tonalIcon(
                    key: Key('download-community-${preset.id}'),
                    onPressed: null,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Saved'),
                  )
                else
                  OutlinedButton.icon(
                    key: Key('download-community-${preset.id}'),
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Save Look'),
                  ),
                const SizedBox(width: Insets.sm),
                FilledButton.icon(
                  key: Key('apply-community-${preset.id}'),
                  onPressed: onApply,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
