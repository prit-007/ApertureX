import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recipe.dart';

/// An in-memory settings clipboard for "copy/paste settings" (Lightroom-style).
class SettingsClipboard extends Notifier<EditRecipe?> {
  @override
  EditRecipe? build() => null;

  void copy(EditRecipe recipe) => state = recipe;

  void clear() => state = null;
}

final settingsClipboardProvider =
    NotifierProvider<SettingsClipboard, EditRecipe?>(SettingsClipboard.new);
