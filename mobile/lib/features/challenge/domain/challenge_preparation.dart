enum RehearsalSpeaker { partner, coach }

class RehearsalOption {
  RehearsalOption({required this.label, required this.nextNodeId}) {
    if (label.trim().isEmpty || nextNodeId.trim().isEmpty) {
      throw const FormatException('Rehearsal option is invalid');
    }
  }

  final String label;
  final String nextNodeId;
}

class RehearsalNode {
  RehearsalNode({
    required this.nodeId,
    required this.speaker,
    required this.text,
    required List<RehearsalOption> options,
    required this.success,
  }) : options = List.unmodifiable(options) {
    if (nodeId.trim().isEmpty || text.trim().isEmpty) {
      throw const FormatException('Rehearsal node is invalid');
    }
    if (success == options.isNotEmpty) {
      throw const FormatException('Rehearsal node transition is invalid');
    }
  }

  final String nodeId;
  final RehearsalSpeaker speaker;
  final String text;
  final List<RehearsalOption> options;
  final bool success;
}

class ChallengeRehearsal {
  ChallengeRehearsal({
    required this.rehearsalId,
    required this.startNodeId,
    required List<RehearsalNode> nodes,
  }) : nodes = List.unmodifiable(nodes) {
    if (rehearsalId.trim().isEmpty || startNodeId.trim().isEmpty) {
      throw const FormatException('Rehearsal identity is invalid');
    }
    final byId = <String, RehearsalNode>{};
    for (final node in nodes) {
      if (byId[node.nodeId] != null) {
        throw const FormatException('Rehearsal nodes must be unique');
      }
      byId[node.nodeId] = node;
    }
    if (!byId.containsKey(startNodeId)) {
      throw const FormatException('Rehearsal start node is missing');
    }
    for (final node in nodes) {
      if (node.options.any((option) => !byId.containsKey(option.nextNodeId))) {
        throw const FormatException('Rehearsal transition target is missing');
      }
    }
    final reachable = <String>{};
    final pending = <String>[startNodeId];
    while (pending.isNotEmpty) {
      final nodeId = pending.removeLast();
      if (!reachable.add(nodeId)) continue;
      pending.addAll(byId[nodeId]!.options.map((option) => option.nextNodeId));
    }
    if (reachable.length != nodes.length ||
        !reachable.any((nodeId) => byId[nodeId]!.success)) {
      throw const FormatException('Rehearsal graph is incomplete');
    }
  }

  final String rehearsalId;
  final String startNodeId;
  final List<RehearsalNode> nodes;

  RehearsalNode node(String nodeId) => nodes.firstWhere(
    (node) => node.nodeId == nodeId,
    orElse: () => throw StateError('Unknown rehearsal node: $nodeId'),
  );
}

class ChallengePreparation {
  ChallengePreparation({
    required this.challengeId,
    required this.guideId,
    required List<String> steps,
    required List<String> phrases,
    required this.exitScript,
    required this.alternateRoute,
    required this.advancedRoute,
    this.rehearsal,
  }) : steps = List.unmodifiable(steps),
       phrases = List.unmodifiable(phrases) {
    if (challengeId.trim().isEmpty ||
        guideId.trim().isEmpty ||
        steps.length != 3 ||
        phrases.length < 3 ||
        phrases.length > 5 ||
        steps.any((step) => step.trim().isEmpty) ||
        phrases.any((phrase) => phrase.trim().isEmpty) ||
        exitScript.trim().isEmpty ||
        alternateRoute.trim().isEmpty ||
        advancedRoute.trim().isEmpty) {
      throw const FormatException('Challenge preparation is invalid');
    }
  }

  final String challengeId;
  final String guideId;
  final List<String> steps;
  final List<String> phrases;
  final String exitScript;
  final String alternateRoute;
  final String advancedRoute;
  final ChallengeRehearsal? rehearsal;
}
