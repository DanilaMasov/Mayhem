import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../domain/artifact_ownership.dart';
import 'season_package_store.dart';

class PresentedFounderArtifact {
  const PresentedFounderArtifact({
    required this.artifactId,
    required this.title,
    required this.unlockedAt,
  });

  final String artifactId;
  final String title;
  final DateTime unlockedAt;
}

class ArtifactOwnershipController extends ChangeNotifier {
  ArtifactOwnershipController({
    required this.ownership,
    required this.packages,
    required this.clock,
  });

  final ArtifactOwnershipRepository ownership;
  final SeasonPackageStore packages;
  final DateTime Function() clock;

  List<PresentedFounderArtifact> _artifacts = const [];
  bool _loading = true;
  String? _error;

  List<PresentedFounderArtifact> get artifacts => _artifacts;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final package = await packages.loadActivePackage(clock().toUtc());
      if (package == null) {
        _artifacts = const [];
        return;
      }
      final definitions = {
        for (final artifact in package.artifacts) artifact.artifactId: artifact,
      };
      final owned = await ownership.loadOwnedArtifacts();
      _artifacts = [
        for (final artifact in owned)
          if (artifact.seasonId == package.season.seasonId &&
              artifact.seasonRevision == package.season.revision &&
              artifact.bossEventId == package.boss.bossEventId &&
              definitions.containsKey(artifact.artifactId))
            PresentedFounderArtifact(
              artifactId: artifact.artifactId,
              title: definitions[artifact.artifactId]!.title,
              unlockedAt: artifact.unlockedAt,
            ),
      ]..sort((left, right) => left.unlockedAt.compareTo(right.unlockedAt));
    } catch (error, stackTrace) {
      _artifacts = const [];
      _error = 'artifact_ownership_load_failed';
      developer.log(
        'Artifact ownership presentation failed closed',
        name: 'mayhem.season.artifact',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
