import 'recipe.dart';

/// Unique identifier for an edit commit node in the DAG.
typedef NodeId = String;

/// An immutable node in the non-linear history Directed Acyclic Graph (DAG).
class HistoryNode {
  const HistoryNode({
    required this.id,
    required this.parentId,
    required this.label,
    required this.recipe,
    required this.timestamp,
    required this.branchName,
    this.metadata,
  });

  factory HistoryNode.fromJson(Map<String, dynamic> json) => HistoryNode(
        id: json['id'] as String,
        parentId: json['parentId'] as String?,
        label: json['label'] as String? ?? 'Edit',
        recipe: EditRecipe.fromJson(json['recipe'] as Map<String, dynamic>),
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now().toUtc(),
        branchName: json['branchName'] as String? ?? 'main',
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  final NodeId id;
  final NodeId? parentId;
  final String label;
  final EditRecipe recipe;
  final DateTime timestamp;
  final String branchName;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'label': label,
        'recipe': recipe.toJson(),
        'timestamp': timestamp.toIso8601String(),
        'branchName': branchName,
        if (metadata != null) 'metadata': metadata,
      };
}

/// A non-linear, Git-style Directed Acyclic Graph (DAG) of non-destructive edits.
///
/// Unlike traditional linear undo stacks which irrevocably truncate the redo tail
/// when an ancestor is modified, [HistoryTree] preserves all historical edits and
/// parallel branches.
class HistoryTree {
  const HistoryTree({
    required this.nodes,
    required this.branches,
    required this.activeBranch,
    required this.currentNodeId,
  });

  /// Initializes a pristine tree with a single root node and 'main' branch.
  factory HistoryTree.initial({
    EditRecipe initialRecipe = EditRecipe.neutral,
    String rootLabel = 'Original',
  }) {
    final rootId = 'root_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final rootNode = HistoryNode(
      id: rootId,
      parentId: null,
      label: rootLabel,
      recipe: initialRecipe,
      timestamp: DateTime.now().toUtc(),
      branchName: 'main',
    );
    return HistoryTree(
      nodes: {rootId: rootNode},
      branches: {'main': rootId},
      activeBranch: 'main',
      currentNodeId: rootId,
    );
  }

  factory HistoryTree.fromJson(Map<String, dynamic> json) {
    final nodesRaw = json['nodes'] as Map<String, dynamic>? ?? {};
    final nodes = nodesRaw.map(
      (k, v) => MapEntry(k, HistoryNode.fromJson(v as Map<String, dynamic>)),
    );
    final branches = Map<String, String>.from(
      json['branches'] as Map? ?? {'main': json['currentNodeId'] as String? ?? 'root'},
    );
    final activeBranch = json['activeBranch'] as String? ?? 'main';
    final currentNodeId = json['currentNodeId'] as String? ??
        (nodes.isNotEmpty ? nodes.keys.first : 'root');

    return HistoryTree(
      nodes: nodes,
      branches: branches,
      activeBranch: activeBranch,
      currentNodeId: currentNodeId,
    );
  }

  /// Map of all committed nodes by their unique [NodeId].
  final Map<NodeId, HistoryNode> nodes;

  /// Pointers mapping branch names (e.g. 'main', 'B&W Moody') to their HEAD [NodeId].
  final Map<String, NodeId> branches;

  /// The active branch currently being edited.
  final String activeBranch;

  /// The currently checked-out / viewed node ID.
  final NodeId currentNodeId;

  /// The currently checked-out [HistoryNode].
  HistoryNode get currentNode =>
      nodes[currentNodeId] ??
      nodes.values.firstWhere(
        (n) => n.parentId == null,
        orElse: () => HistoryNode(
          id: 'root',
          parentId: null,
          label: 'Original',
          recipe: EditRecipe.neutral,
          timestamp: DateTime.now().toUtc(),
          branchName: 'main',
        ),
      );

  /// Linear lineage from the root ancestor up to [currentNodeId].
  ///
  /// Index 0 is always the root, and the last item is [currentNode].
  /// Used for seamless backward compatibility with linear undo/redo stacks.
  List<HistoryNode> get activeLineage {
    final lineage = <HistoryNode>[];
    String? current = currentNodeId;
    while (current != null && nodes.containsKey(current)) {
      final node = nodes[current]!;
      lineage.add(node);
      current = node.parentId;
    }
    return lineage.reversed.toList();
  }

  /// Creates a new named branch pointing at [currentNodeId] and switches to it.
  HistoryTree createBranch(String branchName) {
    final newBranches = Map<String, NodeId>.from(branches);
    newBranches[branchName] = currentNodeId;
    return HistoryTree(
      nodes: nodes,
      branches: newBranches,
      activeBranch: branchName,
      currentNodeId: currentNodeId,
    );
  }

  /// Switches the active branch to [branchName] and sets [currentNodeId] to its head.
  HistoryTree switchBranch(String branchName) {
    if (!branches.containsKey(branchName)) return this;
    final headId = branches[branchName]!;
    return HistoryTree(
      nodes: nodes,
      branches: branches,
      activeBranch: branchName,
      currentNodeId: headId,
    );
  }

  static int _idCounter = 0;

  /// Commits a new recipe state as a child of [currentNodeId] on [activeBranch].
  HistoryTree commit({
    required EditRecipe recipe,
    required String label,
    Map<String, dynamic>? metadata,
  }) {
    _idCounter++;
    final newId =
        'node_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_$_idCounter';
    final newNode = HistoryNode(
      id: newId,
      parentId: currentNodeId,
      label: label,
      recipe: recipe,
      timestamp: DateTime.now().toUtc(),
      branchName: activeBranch,
      metadata: metadata,
    );

    final newNodes = Map<NodeId, HistoryNode>.from(nodes);
    newNodes[newId] = newNode;

    final newBranches = Map<String, NodeId>.from(branches);
    newBranches[activeBranch] = newId;

    return HistoryTree(
      nodes: newNodes,
      branches: newBranches,
      activeBranch: activeBranch,
      currentNodeId: newId,
    );
  }

  /// Jumps to any historical node in the DAG without deleting subsequent commits.
  HistoryTree jumpTo(NodeId nodeId) {
    if (!nodes.containsKey(nodeId)) return this;
    return HistoryTree(
      nodes: nodes,
      branches: branches,
      activeBranch: activeBranch,
      currentNodeId: nodeId,
    );
  }

  /// Returns all direct child nodes for a given [nodeId].
  List<HistoryNode> childrenOf(NodeId nodeId) {
    return nodes.values.where((n) => n.parentId == nodeId).toList();
  }

  /// Deletes a branch pointer. The commits themselves remain in the DAG.
  HistoryTree deleteBranch(String branchName) {
    if (branchName == 'main' || branchName == activeBranch) return this;
    final newBranches = Map<String, NodeId>.from(branches)..remove(branchName);
    return HistoryTree(
      nodes: nodes,
      branches: newBranches,
      activeBranch: activeBranch,
      currentNodeId: currentNodeId,
    );
  }

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((k, v) => MapEntry(k, v.toJson())),
        'branches': branches,
        'activeBranch': activeBranch,
        'currentNodeId': currentNodeId,
      };
}
