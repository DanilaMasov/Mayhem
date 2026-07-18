import '../../../core/sync/event_envelope_v2.dart';
import 'season_participation_state.dart';

abstract interface class SeasonParticipationRepository {
  Future<SeasonParticipationState?> load(String seasonId);

  Future<void> clear(String seasonId);

  Future<void> revertDay(String seasonId, int day);

  Future<void> revertBoss(String seasonId);

  Future<bool> commit({
    required SeasonParticipationState state,
    required EventDraftV2 event,
  });
}
