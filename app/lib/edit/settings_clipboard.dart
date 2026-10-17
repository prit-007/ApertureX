import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parameter.dart';
import 'recipe.dart';
import 'selective_recipe.dart';

/// An in-memory settings clipboard for "copy/paste settings" (Lightroom-style).
class SettingsClipboard extends Notifier<EditRecipe?> {
  Set<RecipeSection>? _selectedSections;

  /// The active sections picked to be copied/pasted. Defaults to all sections
  /// if none were explicitly specified.
  Set<RecipeSection> get selectedSections =>
      _selectedSections ?? RecipeSection.values.toSet();

  @override
  EditRecipe? build() => null;

  /// Copies [recipe] with optional granular [sections]. If [sections] is omitted,
  /// detects and selects modified sections, or all sections if recipe is neutral.
  void copy(EditRecipe recipe, [Set<RecipeSection>? sections]) {
    final s = sections ?? CopiedSettings.detectModifiedSections(recipe);
    _selectedSections = s.isEmpty ? RecipeSection.values.toSet() : s;
    state = recipe;
  }

  /// Updates the subset of sections to apply during paste.
  void setSections(Set<RecipeSection> sections) {
    _selectedSections = sections;
  }

  void clear() {
    _selectedSections = null;
    state = null;
  }

  /// Returns the current [CopiedSettings] representation, or null if clipboard is empty.
  CopiedSettings? get copiedSettings => state == null
      ? null
      : CopiedSettings(recipe: state!, sections: selectedSections);
}

final settingsClipboardProvider =
    NotifierProvider<SettingsClipboard, EditRecipe?>(SettingsClipboard.new);
