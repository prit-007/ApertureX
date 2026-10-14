import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/edit/recipe.dart';
import 'package:tessera/edit/recipe_store.dart';

void main() {
  test('put/get and pasteTo', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(recipeStoreProvider.notifier);

    store.put('a', EditRecipe.neutral.copyWith(exposure: 1));
    expect(store.recipeFor('a')!.exposure, 1);

    store.pasteTo(['b', 'c'], EditRecipe.neutral.copyWith(contrast: 0.5));
    final map = container.read(recipeStoreProvider);
    expect(map['b']!.contrast, 0.5);
    expect(map['c']!.contrast, 0.5);
    expect(map['a']!.exposure, 1); // untouched
  });

  test('clear empties the store', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(recipeStoreProvider.notifier);
    store.put('a', EditRecipe.neutral);
    store.clear();
    expect(container.read(recipeStoreProvider), isEmpty);
  });

  test('a neutral recipe is stored as absence (no spurious edits)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(recipeStoreProvider.notifier);

    store.put('a', EditRecipe.neutral.copyWith(exposure: 1));
    expect(container.read(recipeStoreProvider).containsKey('a'), isTrue);

    // Editing back to neutral clears the entry (so it is not "edited").
    store.put('a', EditRecipe.neutral);
    expect(container.read(recipeStoreProvider).containsKey('a'), isFalse);
  });

  test('put with an unchanged recipe leaves state identity intact', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(recipeStoreProvider.notifier);
    final recipe = EditRecipe.neutral.copyWith(contrast: 0.4);

    store.put('a', recipe);
    final first = container.read(recipeStoreProvider);
    store.put('a', recipe);
    expect(identical(first, container.read(recipeStoreProvider)), isTrue);
  });

  test('pasteTo neutral clears existing entries', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(recipeStoreProvider.notifier);
    store.put('a', EditRecipe.neutral.copyWith(exposure: 1));
    store.pasteTo(['a'], EditRecipe.neutral);
    expect(container.read(recipeStoreProvider), isEmpty);
  });
}
