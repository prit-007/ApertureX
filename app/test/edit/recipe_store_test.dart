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
}
