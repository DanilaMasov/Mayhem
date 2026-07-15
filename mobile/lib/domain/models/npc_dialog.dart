enum DialogSpeaker {
  npc,
  coach;

  static DialogSpeaker fromWire(String value) {
    return DialogSpeaker.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw FormatException('Unknown dialog speaker: $value'),
    );
  }
}

class DialogOption {
  const DialogOption({required this.label, required this.nextNodeId});

  factory DialogOption.fromJson(Map<String, dynamic> json) {
    return DialogOption(
      label: _requiredString(json, 'label'),
      nextNodeId: _requiredString(json, 'nextNodeId'),
    );
  }

  final String label;
  final String nextNodeId;
}

class DialogNode {
  const DialogNode({
    required this.id,
    required this.speaker,
    required this.text,
    required this.options,
    required this.success,
  });

  factory DialogNode.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    if (rawOptions is! List<dynamic>) {
      throw const FormatException('Dialog node options must be an array');
    }
    return DialogNode(
      id: _requiredString(json, 'id'),
      speaker: DialogSpeaker.fromWire(_requiredString(json, 'speaker')),
      text: _requiredString(json, 'text'),
      options: rawOptions
          .map((item) => DialogOption.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      success: json['success'] == true,
    );
  }

  final String id;
  final DialogSpeaker speaker;
  final String text;
  final List<DialogOption> options;
  final bool success;
}

class NpcDialog {
  NpcDialog({
    required this.id,
    required this.questId,
    required this.startNodeId,
    required this.nodes,
  }) {
    _validateGraph();
    _byId = {for (final node in nodes) node.id: node};
  }

  factory NpcDialog.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'];
    if (rawNodes is! List<dynamic>) {
      throw const FormatException('Dialog nodes must be an array');
    }
    return NpcDialog(
      id: _requiredString(json, 'id'),
      questId: _requiredString(json, 'questId'),
      startNodeId: _requiredString(json, 'startNodeId'),
      nodes: rawNodes
          .map((item) => DialogNode.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String id;
  final String questId;
  final String startNodeId;
  final List<DialogNode> nodes;
  late final Map<String, DialogNode> _byId;

  DialogNode node(String id) {
    final result = _byId[id];
    if (result == null) {
      throw StateError('Unknown dialog node: $id');
    }
    return result;
  }

  void _validateGraph() {
    if (nodes.isEmpty) {
      throw FormatException('$id has no nodes');
    }
    final byId = <String, DialogNode>{};
    for (final node in nodes) {
      if (byId.containsKey(node.id)) {
        throw FormatException('$id contains duplicate node: ${node.id}');
      }
      byId[node.id] = node;
    }
    if (!byId.containsKey(startNodeId)) {
      throw FormatException('$id start node does not exist: $startNodeId');
    }
    for (final node in nodes) {
      if (node.success && node.options.isNotEmpty) {
        throw FormatException(
          '$id success node ${node.id} must not have options',
        );
      }
      if (!node.success && node.options.isEmpty) {
        throw FormatException('$id node ${node.id} is a dead end');
      }
      for (final option in node.options) {
        if (!byId.containsKey(option.nextNodeId)) {
          throw FormatException(
            '$id points to unknown node: ${option.nextNodeId}',
          );
        }
      }
    }

    final reachable = <String>{};
    final pending = <String>[startNodeId];
    while (pending.isNotEmpty) {
      final nodeId = pending.removeLast();
      if (!reachable.add(nodeId)) {
        continue;
      }
      pending.addAll(byId[nodeId]!.options.map((option) => option.nextNodeId));
    }
    if (reachable.length != nodes.length) {
      throw FormatException('$id contains unreachable nodes');
    }
    if (!reachable.any((nodeId) => byId[nodeId]!.success)) {
      throw FormatException('$id has no reachable success node');
    }
  }
}

class DialogCatalog {
  DialogCatalog({required this.schemaVersion, required this.dialogs}) {
    _validate();
    _byQuestId = {for (final dialog in dialogs) dialog.questId: dialog};
  }

  final int schemaVersion;
  final List<NpcDialog> dialogs;
  late final Map<String, NpcDialog> _byQuestId;

  NpcDialog forQuest(String questId) {
    final dialog = _byQuestId[questId];
    if (dialog == null) {
      throw StateError('Dialog is missing for quest: $questId');
    }
    return dialog;
  }

  bool hasDialog(String questId) => _byQuestId.containsKey(questId);

  void validateCoverage(Iterable<String> eligibleQuestIds) {
    final expected = eligibleQuestIds.toSet();
    final actual = _byQuestId.keys.toSet();
    final missing = expected.difference(actual);
    final unknown = actual.difference(expected);
    if (missing.isNotEmpty) {
      throw FormatException('Missing dialogs: ${missing.join(', ')}');
    }
    if (unknown.isNotEmpty) {
      throw FormatException(
        'Dialogs reference ineligible quests: ${unknown.join(', ')}',
      );
    }
  }

  void _validate() {
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported dialog catalog schema: $schemaVersion',
      );
    }
    if (dialogs.isEmpty) {
      throw const FormatException('Dialog catalog must not be empty');
    }
    final ids = <String>{};
    final questIds = <String>{};
    for (final dialog in dialogs) {
      if (!ids.add(dialog.id)) {
        throw FormatException('Duplicate dialog id: ${dialog.id}');
      }
      if (!questIds.add(dialog.questId)) {
        throw FormatException('Duplicate dialog questId: ${dialog.questId}');
      }
    }
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value.trim();
}
