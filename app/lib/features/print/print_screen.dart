import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../viewport/soft_proofing.dart';
import 'print_model.dart';
import 'print_pdf_generator.dart';

/// Provider holding the active Print Job configuration.
final printJobConfigProvider =
    NotifierProvider<PrintJobConfigNotifier, PrintJobConfig>(
  PrintJobConfigNotifier.new,
);

class PrintJobConfigNotifier extends Notifier<PrintJobConfig> {
  @override
  PrintJobConfig build() => const PrintJobConfig();

  void setPaperSize(PaperSize size) => state = state.copyWith(paperSize: size);
  void setOrientation(PrintOrientation orientation) =>
      state = state.copyWith(orientation: orientation);
  void setLayoutMode(PrintLayoutMode mode) =>
      state = state.copyWith(layoutMode: mode);
  void setMargins(PrintMargins margins) =>
      state = state.copyWith(margins: margins);
  void setGrid(ContactSheetGrid grid) =>
      state = state.copyWith(contactSheetGrid: grid);
  void setColorManagement(PrintColorManagement cm) =>
      state = state.copyWith(colorManagement: cm);
  void toggleCutMarks() =>
      state = state.copyWith(renderCutMarks: !state.renderCutMarks);
  void togglePageNumbers() =>
      state = state.copyWith(renderPageNumbers: !state.renderPageNumbers);
  void toggleCaptions() =>
      state = state.copyWith(renderCaptions: !state.renderCaptions);
}

/// Professional Print & Contact Sheet Studio screen.
class PrintScreen extends ConsumerStatefulWidget {
  const PrintScreen({
    super.key,
    required this.items,
    this.initialConfig,
  });

  final List<PrintPhotoItem> items;
  final PrintJobConfig? initialConfig;

  @override
  ConsumerState<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends ConsumerState<PrintScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentPageIndex = 0;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf(PrintJobConfig config) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = PrintPdfGenerator.generate(
        config: config,
        items: widget.items,
      );
      setState(() {
        _isGeneratingPdf = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF Generated successfully (${(pdf.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGeneratingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(printJobConfigProvider);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final totalPages = config.layoutMode == PrintLayoutMode.contactSheet
        ? config.contactSheetGrid.pageCountFor(widget.items.length)
        : (widget.items.isEmpty ? 1 : widget.items.length);

    if (_currentPageIndex >= totalPages) {
      _currentPageIndex = (totalPages - 1).clamp(0, totalPages);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print & Contact Sheet Studio'),
        actions: [
          IconButton(
            key: const Key('soft-proof-quick-toggle'),
            tooltip: 'Toggle Soft Proofing',
            icon: Icon(
              config.colorManagement.enabled
                  ? Icons.remove_red_eye
                  : Icons.remove_red_eye_outlined,
              color: config.colorManagement.enabled
                  ? theme.colorScheme.primary
                  : null,
            ),
            onPressed: () {
              ref.read(printJobConfigProvider.notifier).setColorManagement(
                    config.colorManagement.copyWith(
                      enabled: !config.colorManagement.enabled,
                    ),
                  );
            },
          ),
          FilledButton.icon(
            key: const Key('generate-pdf-btn'),
            onPressed: _isGeneratingPdf ? null : () => _generatePdf(config),
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export PDF'),
          ),
          const SizedBox(width: Insets.md),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildPreviewArea(config, totalPages),
                ),
                VerticalDivider(width: 1, color: theme.dividerColor),
                SizedBox(
                  width: 360,
                  child: _buildControlsPanel(config),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  flex: 4,
                  child: _buildPreviewArea(config, totalPages),
                ),
                Divider(height: 1, color: theme.dividerColor),
                Expanded(
                  flex: 5,
                  child: _buildControlsPanel(config),
                ),
              ],
            ),
    );
  }

  Widget _buildPreviewArea(PrintJobConfig config, int totalPages) {
    final theme = Theme.of(context);
    final dims = config.paperDimensions;
    final paperAspect = dims.width / dims.height;

    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        children: [
          // Pagination HUD
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('prev-page-btn'),
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPageIndex > 0
                    ? () => setState(() => _currentPageIndex--)
                    : null,
              ),
              Text(
                'Page ${_currentPageIndex + 1} of $totalPages',
                style: theme.textTheme.titleSmall,
              ),
              IconButton(
                key: const Key('next-page-btn'),
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPageIndex < totalPages - 1
                    ? () => setState(() => _currentPageIndex++)
                    : null,
              ),
              const SizedBox(width: Insets.lg),
              Chip(
                label: Text(
                  '${config.paperSize.displayName} · ${config.orientation.name.toUpperCase()}',
                  style: theme.textTheme.labelSmall,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),

          // WYSIWYG Paper Canvas
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: paperAspect,
                child: Container(
                  decoration: BoxDecoration(
                    color: config.colorManagement.enabled &&
                            config.colorManagement.simulatePaperAndInk
                        ? const Color(0xFFFAF7F2) // Warm matte paper white
                        : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildPaperContent(
                          config: config,
                          constraints: constraints,
                          paperDims: dims,
                          pageIdx: _currentPageIndex,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperContent({
    required PrintJobConfig config,
    required BoxConstraints constraints,
    required Size paperDims,
    required int pageIdx,
  }) {
    final scale = constraints.maxWidth / paperDims.width;
    final printable = config.printableArea;

    final printLeft = printable.left * scale;
    final printTop = printable.top * scale;
    final printWidth = printable.width * scale;
    final printHeight = printable.height * scale;

    return Stack(
      children: [
        // Margin border guide
        Positioned(
          left: printLeft,
          top: printTop,
          width: printWidth,
          height: printHeight,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.35),
                style: BorderStyle.solid,
                width: 1,
              ),
            ),
          ),
        ),

        // Photos rendering
        if (config.layoutMode == PrintLayoutMode.contactSheet)
          _buildContactSheetPreview(
            config: config,
            printLeft: printLeft,
            printTop: printTop,
            printWidth: printWidth,
            printHeight: printHeight,
            pageIdx: pageIdx,
          )
        else
          _buildSinglePhotoPreview(
            config: config,
            printLeft: printLeft,
            printTop: printTop,
            printWidth: printWidth,
            printHeight: printHeight,
            pageIdx: pageIdx,
          ),

        // Page number
        if (config.renderPageNumbers)
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Text(
              '- ${pageIdx + 1} -',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Gamut warning badge if active
        if (config.colorManagement.enabled &&
            config.colorManagement.gamutWarning)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: config.colorManagement.warningColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'GAMUT WARNING',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSinglePhotoPreview({
    required PrintJobConfig config,
    required double printLeft,
    required double printTop,
    required double printWidth,
    required double printHeight,
    required int pageIdx,
  }) {
    if (widget.items.isEmpty) {
      return Positioned(
        left: printLeft,
        top: printTop,
        width: printWidth,
        height: printHeight,
        child: const Center(
          child: Text(
            'No Photo Selected',
            style: TextStyle(color: Colors.black38),
          ),
        ),
      );
    }

    final photo = widget.items[pageIdx.clamp(0, widget.items.length - 1)];

    return Positioned(
      left: printLeft,
      top: printTop,
      width: printWidth,
      height: printHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: photo.imageBytes != null
                  ? Image.memory(
                      photo.imageBytes!,
                      fit: BoxFit.contain,
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.black38),
                      ),
                    ),
            ),
            if (config.renderCaptions &&
                (photo.filename.isNotEmpty || photo.exifSummary.isNotEmpty)) ...[
              const SizedBox(height: 4),
              Text(
                photo.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactSheetPreview({
    required PrintJobConfig config,
    required double printLeft,
    required double printTop,
    required double printWidth,
    required double printHeight,
    required int pageIdx,
  }) {
    final grid = config.contactSheetGrid;
    final startIdx = pageIdx * grid.itemsPerPage;
    final endIdx = (startIdx + grid.itemsPerPage).clamp(0, widget.items.length);
    final pagePhotos =
        widget.items.isEmpty ? <PrintPhotoItem>[] : widget.items.sublist(startIdx, endIdx);

    return Positioned(
      left: printLeft,
      top: printTop,
      width: printWidth,
      height: printHeight,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: grid.columns,
          mainAxisSpacing: grid.spacingPoints / 2,
          crossAxisSpacing: grid.spacingPoints / 2,
          childAspectRatio: 0.85,
        ),
        itemCount: grid.itemsPerPage,
        itemBuilder: (context, i) {
          if (i >= pagePhotos.length) {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }
          final photo = pagePhotos[i];
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: grid.strokeBorder ? Colors.black26 : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            padding: const EdgeInsets.all(2),
            child: Column(
              children: [
                Expanded(
                  child: photo.imageBytes != null
                      ? Image.memory(photo.imageBytes!, fit: BoxFit.contain)
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.image, size: 20, color: Colors.black38),
                          ),
                        ),
                ),
                if (grid.showFilename && photo.filename.isNotEmpty)
                  Text(
                    photo.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlsPanel(PrintJobConfig config) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Paper'),
            Tab(text: 'Layout'),
            Tab(text: 'Color / Proof'),
            Tab(text: 'Captions'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPaperTab(config),
              _buildLayoutTab(config),
              _buildColorProofTab(config),
              _buildCaptionsTab(config),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaperTab(PrintJobConfig config) {
    final notifier = ref.read(printJobConfigProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Text('Paper Size', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        DropdownButtonFormField<PaperSize>(
          isExpanded: true,
          initialValue: config.paperSize,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: PaperSize.values.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text(s.displayName, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) notifier.setPaperSize(val);
          },
        ),
        const SizedBox(height: Insets.md),
        Text('Orientation', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        SegmentedButton<PrintOrientation>(
          segments: const [
            ButtonSegment(
              value: PrintOrientation.portrait,
              label: Text('Portrait'),
              icon: Icon(Icons.portrait),
            ),
            ButtonSegment(
              value: PrintOrientation.landscape,
              label: Text('Landscape'),
              icon: Icon(Icons.landscape),
            ),
          ],
          selected: {config.orientation},
          onSelectionChanged: (set) => notifier.setOrientation(set.first),
        ),
        const SizedBox(height: Insets.md),
        SwitchListTile(
          title: const Text('Cut Marks'),
          subtitle: const Text('Render corner crop/trim guidelines'),
          value: config.renderCutMarks,
          onChanged: (_) => notifier.toggleCutMarks(),
        ),
        SwitchListTile(
          title: const Text('Page Numbers'),
          subtitle: const Text('Print pagination at bottom of page'),
          value: config.renderPageNumbers,
          onChanged: (_) => notifier.togglePageNumbers(),
        ),
      ],
    );
  }

  Widget _buildLayoutTab(PrintJobConfig config) {
    final notifier = ref.read(printJobConfigProvider.notifier);
    final grid = config.contactSheetGrid;

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Text('Layout Mode', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        SegmentedButton<PrintLayoutMode>(
          segments: const [
            ButtonSegment(
              value: PrintLayoutMode.single,
              label: Text('Single Photo'),
              icon: Icon(Icons.photo),
            ),
            ButtonSegment(
              value: PrintLayoutMode.contactSheet,
              label: Text('Contact Sheet'),
              icon: Icon(Icons.grid_view),
            ),
          ],
          selected: {config.layoutMode},
          onSelectionChanged: (set) => notifier.setLayoutMode(set.first),
        ),
        const SizedBox(height: Insets.md),
        if (config.layoutMode == PrintLayoutMode.contactSheet) ...[
          Text('Grid Dimensions', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text('Rows: ${grid.rows}'),
                  subtitle: Slider(
                    min: 1,
                    max: 8,
                    divisions: 7,
                    value: grid.rows.toDouble(),
                    onChanged: (v) => notifier.setGrid(
                      grid.copyWith(rows: v.round()),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListTile(
                  title: Text('Columns: ${grid.columns}'),
                  subtitle: Slider(
                    min: 1,
                    max: 8,
                    divisions: 7,
                    value: grid.columns.toDouble(),
                    onChanged: (v) => notifier.setGrid(
                      grid.copyWith(columns: v.round()),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('Cell Borders'),
            value: grid.strokeBorder,
            onChanged: (v) => notifier.setGrid(grid.copyWith(strokeBorder: v)),
          ),
          const Divider(),
        ],
        Text('Margins (mm)', style: Theme.of(context).textTheme.titleSmall),
        ListTile(
          title: Text('All Margins: ${config.margins.topMm.toStringAsFixed(1)} mm'),
          subtitle: Slider(
            min: 0,
            max: 30,
            divisions: 30,
            value: config.margins.topMm,
            onChanged: (v) => notifier.setMargins(
              PrintMargins.uniform(v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorProofTab(PrintJobConfig config) {
    final notifier = ref.read(printJobConfigProvider.notifier);
    final cm = config.colorManagement;

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        SwitchListTile(
          title: const Text('Enable Soft Proofing'),
          subtitle: const Text('Simulate target printer & paper output'),
          value: cm.enabled,
          onChanged: (v) => notifier.setColorManagement(cm.copyWith(enabled: v)),
        ),
        const SizedBox(height: Insets.sm),
        Text('Target Profile / ICC', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        DropdownButtonFormField<ProofProfile>(
          isExpanded: true,
          initialValue: cm.profile,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ProofProfile.values.map((p) {
            return DropdownMenuItem(
              value: p,
              child: Text(p.displayName, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: cm.enabled
              ? (val) {
                  if (val != null) {
                    notifier.setColorManagement(cm.copyWith(profile: val));
                  }
                }
              : null,
        ),
        const SizedBox(height: Insets.md),
        Text('Rendering Intent', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        DropdownButtonFormField<ProofIntent>(
          isExpanded: true,
          initialValue: cm.intent,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ProofIntent.values.map((i) {
            return DropdownMenuItem(
              value: i,
              child: Text(i.displayName, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: cm.enabled
              ? (val) {
                  if (val != null) {
                    notifier.setColorManagement(cm.copyWith(intent: val));
                  }
                }
              : null,
        ),
        const SizedBox(height: Insets.md),
        SwitchListTile(
          title: const Text('Simulate Paper & Ink'),
          subtitle: const Text('Simulate paper white point & ink DMax black limit'),
          value: cm.simulatePaperAndInk,
          onChanged: cm.enabled
              ? (v) => notifier.setColorManagement(cm.copyWith(simulatePaperAndInk: v))
              : null,
        ),
        SwitchListTile(
          title: const Text('Gamut Warning'),
          subtitle: const Text('Highlight colors exceeding target printer gamut'),
          value: cm.gamutWarning,
          onChanged: cm.enabled
              ? (v) => notifier.setColorManagement(cm.copyWith(gamutWarning: v))
              : null,
        ),
      ],
    );
  }

  Widget _buildCaptionsTab(PrintJobConfig config) {
    final notifier = ref.read(printJobConfigProvider.notifier);
    final grid = config.contactSheetGrid;

    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        SwitchListTile(
          title: const Text('Show Captions'),
          subtitle: const Text('Include metadata annotations under photos'),
          value: config.renderCaptions,
          onChanged: (_) => notifier.toggleCaptions(),
        ),
        if (config.layoutMode == PrintLayoutMode.contactSheet) ...[
          SwitchListTile(
            title: const Text('Filename'),
            value: grid.showFilename,
            onChanged: config.renderCaptions
                ? (v) => notifier.setGrid(grid.copyWith(showFilename: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('EXIF Exposure'),
            subtitle: const Text('Shutter, aperture, and ISO settings'),
            value: grid.showExif,
            onChanged: config.renderCaptions
                ? (v) => notifier.setGrid(grid.copyWith(showExif: v))
                : null,
          ),
        ],
      ],
    );
  }
}
