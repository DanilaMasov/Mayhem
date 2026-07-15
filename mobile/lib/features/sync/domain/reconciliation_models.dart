import '../../../content/domain/content_item_revision.dart';
import '../../progress/domain/progress_models.dart';
import '../../season/domain/artifact_ownership.dart';
import '../../streak/domain/momentum_state.dart';

class PendingChallengeDescriptor {
  PendingChallengeDescriptor({
    required this.primaryTrait,
    required this.intensity,
    required Map<Trait, double> secondaryTraitWeights,
  }) : secondaryTraitWeights = Map.unmodifiable(secondaryTraitWeights) {
    if (intensity < 1 || intensity > 5) {
      throw const FormatException('Pending challenge intensity is invalid');
    }
  }

  factory PendingChallengeDescriptor.fromContent(ContentItemRevision revision) {
    final primary = revision.payload['primaryTrait'];
    final intensity = revision.payload['intensity'];
    if (primary is! String || intensity is! int) {
      throw const FormatException(
        'Challenge reconciliation metadata is missing',
      );
    }
    final secondary = revision.payload['secondaryTraitWeights'];
    final weights = <Trait, double>{};
    if (secondary is Map) {
      for (final entry in secondary.entries) {
        weights[Trait.values.byName(entry.key as String)] = (entry.value as num)
            .toDouble();
      }
    }
    return PendingChallengeDescriptor(
      primaryTrait: Trait.values.byName(primary),
      intensity: intensity,
      secondaryTraitWeights: weights,
    );
  }

  final Trait primaryTrait;
  final int intensity;
  final Map<Trait, double> secondaryTraitWeights;
}

enum CorrectionReason {
  serverProjectionCorrected,
  rankCorrected,
  timezoneCorrection;

  String get wireName => switch (this) {
    CorrectionReason.serverProjectionCorrected => 'server_projection_corrected',
    CorrectionReason.rankCorrected => 'rank_corrected',
    CorrectionReason.timezoneCorrection => 'timezone_correction',
  };
}

class CorrectionNotice {
  CorrectionNotice({
    required this.noticeId,
    required Set<CorrectionReason> reasons,
    required this.createdAt,
  }) : reasons = Set.unmodifiable(reasons);

  final String noticeId;
  final Set<CorrectionReason> reasons;
  final DateTime createdAt;
}

class ReconciledState {
  ReconciledState({
    required this.projection,
    required this.momentum,
    required this.serverProjectionRevision,
    required this.applied,
    List<OwnedFounderArtifact> ownedArtifacts = const [],
    this.correctionNotice,
  }) : ownedArtifacts = List.unmodifiable(ownedArtifacts) {
    if (!applied && ownedArtifacts.isNotEmpty) {
      throw const FormatException(
        'Stale reconciliation cannot replace artifact ownership',
      );
    }
  }

  final ProgressProjection projection;
  final MomentumState momentum;
  final int serverProjectionRevision;
  final bool applied;
  final List<OwnedFounderArtifact> ownedArtifacts;
  final CorrectionNotice? correctionNotice;
}

abstract interface class ProjectionReconciliationStore {
  Future<int> loadLastServerProjectionRevision();

  Future<void> commit(ReconciledState state);

  Future<CorrectionNotice?> takePendingCorrectionNotice();
}
