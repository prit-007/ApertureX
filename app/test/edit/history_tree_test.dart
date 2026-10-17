import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/history_tree.dart';
import 'package:aperturex/edit/recipe.dart';

void main() {
  group('HistoryTree DAG model', () {
    test('initial tree starts with root node and main branch', () {
      final tree = HistoryTree.initial();
      expect(tree.nodes.length, 1);
      expect(tree.branches.length, 1);
      expect(tree.branches['main'], tree.currentNodeId);
      expect(tree.activeBranch, 'main');

      final root = tree.currentNode;
      expect(root.parentId, isNull);
      expect(root.label, 'Original');
      expect(root.recipe, EditRecipe.neutral);
      expect(tree.activeLineage.length, 1);
      expect(tree.activeLineage.first.id, root.id);
    });

    test('committing creates child node and advances branch head', () {
      final tree0 = HistoryTree.initial();
      final recipe1 = EditRecipe.neutral.copyWith(exposure: 1.0);
      final tree1 = tree0.commit(recipe: recipe1, label: 'Exposure +1.0');

      expect(tree1.nodes.length, 2);
      expect(tree1.activeLineage.length, 2);
      expect(tree1.currentNode.label, 'Exposure +1.0');
      expect(tree1.currentNode.parentId, tree0.currentNodeId);
      expect(tree1.branches['main'], tree1.currentNodeId);

      final recipe2 = recipe1.copyWith(contrast: 0.5);
      final tree2 = tree1.commit(recipe: recipe2, label: 'Contrast +0.5');

      expect(tree2.nodes.length, 3);
      expect(tree2.activeLineage.length, 3);
      expect(tree2.currentNode.label, 'Contrast +0.5');
      expect(tree2.currentNode.parentId, tree1.currentNodeId);
    });

    test('jumping to an earlier node does not delete subsequent commits (no destructive truncation)', () {
      final r0 = EditRecipe.neutral;
      final r1 = r0.copyWith(exposure: 0.5);
      final r2 = r1.copyWith(contrast: 0.2);

      final tree = HistoryTree.initial()
          .commit(recipe: r1, label: 'Step 1')
          .commit(recipe: r2, label: 'Step 2');

      final step1Id = tree.activeLineage[1].id;
      final steppedBack = tree.jumpTo(step1Id);

      expect(steppedBack.currentNodeId, step1Id);
      expect(steppedBack.currentNode.label, 'Step 1');
      // All 3 nodes are preserved!
      expect(steppedBack.nodes.length, 3);
      expect(steppedBack.activeLineage.length, 2);
    });

    test('committing from an ancestor creates a branch fork without destroying existing commits', () {
      final r0 = EditRecipe.neutral;
      final r1 = r0.copyWith(exposure: 0.5);
      final r2 = r1.copyWith(contrast: 0.2);

      final tree = HistoryTree.initial()
          .commit(recipe: r1, label: 'Step 1')
          .commit(recipe: r2, label: 'Step 2');

      final step1Id = tree.activeLineage[1].id;
      final step2Id = tree.activeLineage[2].id;

      // Jump back to Step 1
      final steppedBack = tree.jumpTo(step1Id);

      // Make a different edit from Step 1
      final r3 = r1.copyWith(saturation: -1.0);
      final forked = steppedBack.commit(recipe: r3, label: 'Step 1 Fork B&W');

      // Both Step 2 and Step 1 Fork B&W must exist in the DAG!
      expect(forked.nodes.containsKey(step2Id), isTrue);
      expect(forked.currentNode.label, 'Step 1 Fork B&W');
      expect(forked.currentNode.parentId, step1Id);
      expect(forked.nodes.length, 4); // Root, Step 1, Step 2, Step 1 Fork B&W
    });

    test('createBranch and switchBranch support parallel workflows', () {
      final r0 = EditRecipe.neutral;
      final r1 = r0.copyWith(exposure: 0.5);

      var tree = HistoryTree.initial().commit(recipe: r1, label: 'Base Exposure');
      final baseNodeId = tree.currentNodeId;

      // Create branch 'bw-moody' from baseNodeId
      tree = tree.createBranch('bw-moody');
      expect(tree.branches.containsKey('bw-moody'), isTrue);
      expect(tree.branches['bw-moody'], baseNodeId);
      expect(tree.activeBranch, 'bw-moody');

      // Commit on bw-moody
      final rBw = r1.copyWith(saturation: -1.0);
      tree = tree.commit(recipe: rBw, label: 'B&W Desaturate');
      final bwHeadId = tree.currentNodeId;
      expect(tree.branches['bw-moody'], bwHeadId);
      expect(tree.branches['main'], baseNodeId);

      // Switch back to main
      tree = tree.switchBranch('main');
      expect(tree.activeBranch, 'main');
      expect(tree.currentNodeId, baseNodeId);
      expect(tree.currentNode.recipe.saturation, 0.0);

      // Commit on main
      final rWarm = r1.copyWith(temperature: 0.4);
      tree = tree.commit(recipe: rWarm, label: 'Warm Sun');
      final warmHeadId = tree.currentNodeId;
      expect(tree.branches['main'], warmHeadId);

      // Switch back to bw-moody
      tree = tree.switchBranch('bw-moody');
      expect(tree.activeBranch, 'bw-moody');
      expect(tree.currentNodeId, bwHeadId);
      expect(tree.currentNode.recipe.saturation, -1.0);
    });

    test('childrenOf returns all direct child nodes of a given node', () {
      final tree0 = HistoryTree.initial();
      final rootId = tree0.currentNodeId;

      final tree1 = tree0.commit(recipe: EditRecipe.neutral.copyWith(exposure: 0.5), label: 'Child A');
      final tree2 = tree1.jumpTo(rootId).commit(recipe: EditRecipe.neutral.copyWith(contrast: 0.5), label: 'Child B');

      final rootChildren = tree2.childrenOf(rootId);
      expect(rootChildren.length, 2);
      expect(rootChildren.map((c) => c.label).toSet(), {'Child A', 'Child B'});
    });

    test('JSON serialization round-trips DAG tree, branches, and active pointers', () {
      final r0 = EditRecipe.neutral;
      final r1 = r0.copyWith(exposure: 0.8);
      final r2 = r1.copyWith(saturation: -0.5);

      final originalTree = HistoryTree.initial()
          .commit(recipe: r1, label: 'Exposure +0.8')
          .createBranch('film-look')
          .commit(recipe: r2, label: 'Desaturate');

      final json = originalTree.toJson();
      final restoredTree = HistoryTree.fromJson(json);

      expect(restoredTree.activeBranch, originalTree.activeBranch);
      expect(restoredTree.currentNodeId, originalTree.currentNodeId);
      expect(restoredTree.nodes.length, originalTree.nodes.length);
      expect(restoredTree.branches, originalTree.branches);
      expect(restoredTree.currentNode.label, 'Desaturate');
      expect(restoredTree.currentNode.recipe.saturation, -0.5);
    });
  });
}
