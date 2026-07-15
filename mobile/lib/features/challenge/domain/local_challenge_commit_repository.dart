import '../../../core/sync/event_envelope_v2.dart';
import '../../progress/domain/progress_models.dart';
import '../../reflection/domain/private_reflection.dart';
import '../../streak/domain/momentum_state.dart';
import 'challenge_models.dart';

abstract interface class LocalChallengeCommitRepository {
  Future<bool> commitAccepted({
    required ChallengeAttempt attempt,
    required EventDraftV2 event,
  });

  Future<bool> commitResolution({
    required ChallengeAttempt attempt,
    required ProgressProjection projection,
    required MomentumState momentum,
    required List<EventDraftV2> events,
    PrivateReflection? reflection,
  });
}
