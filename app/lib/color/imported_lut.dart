import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lut_atlas.dart';

/// The user-imported grade LUT (a preset "look"). While set, the canvas samples
/// this atlas instead of the recipe-baked one (replace-mode v1); clearing it
/// returns to the recipe grade.
class ImportedLutController extends Notifier<LutAtlas?> {
  @override
  LutAtlas? build() => null;

  void apply(LutAtlas atlas) => state = atlas;

  void clear() => state = null;
}

final importedLutProvider =
    NotifierProvider<ImportedLutController, LutAtlas?>(ImportedLutController.new);
