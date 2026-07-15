import 'package:flutter/foundation.dart';

import '../../content/data/bundled_vnext_content_adapter.dart';
import '../../core/clock/mayhem_clock.dart';
import '../../core/feature_flags/feature_flag_runtime.dart';
import '../../core/identity/local_identity_repository.dart';
import '../../features/challenge/application/challenge_flow_coordinator.dart';
import '../../features/challenge/domain/reward_policy.dart';
import '../../features/feed/application/feed_challenge_controller.dart';
import '../../features/feed/application/feed_interaction_coordinator.dart';
import '../../features/feed/application/feed_session_coordinator.dart';
import '../../features/feed/application/feed_view_controller.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/data/local_onboarding_repository.dart';
import '../../features/progress/application/journey_controller.dart';
import '../../features/progress/domain/development_rank_config.dart';
import '../../features/season/application/artifact_ownership_controller.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/data/local_user_preferences_repository.dart';
import '../../infrastructure/sqlite/sqlite_vnext_store.dart';

class VNextRuntime extends ChangeNotifier {
  static const _lastSeenRankKey = 'last_seen_rank_v1';
  factory VNextRuntime({
    required SqliteVNextStore store,
    required BundledVNextContent bundled,
    required FeatureFlagRuntime featureFlags,
    required String Function() idGenerator,
    required MayhemClock clock,
    int Function()? timezoneOffsetMinutes,
  }) {
    final currentTime = clock.localNow;
    final onboarding = OnboardingController(
      repository: LocalOnboardingRepository(store.metadata),
      progressRepository: store.progress,
      clock: currentTime,
    );
    final feed = FeedViewController(
      coordinator: FeedSessionCoordinator(
        content: store.content,
        feed: store.feed,
        attempts: store.challenge,
        identity: store.identity,
        idGenerator: idGenerator,
      ),
      bundled: bundled,
      metadata: store.metadata,
      clock: currentTime,
      interactions: FeedInteractionCoordinator(
        repository: store.feed,
        idGenerator: idGenerator,
      ),
      interactionClock: clock,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
    );
    final journey = JourneyController(
      progress: store.progress,
      momentum: store.momentum,
      attempts: store.challenge,
      reflections: store.reflection,
      bundled: bundled,
      clock: currentTime,
    );
    final settings = SettingsController(
      LocalUserPreferencesRepository(store.metadata),
    );
    final artifacts = ArtifactOwnershipController(
      ownership: store.reconciliation,
      packages: store.season,
      clock: currentTime,
    );
    late final VNextRuntime runtime;
    final feedChallenge = FeedChallengeController(
      flow: ChallengeFlowCoordinator(
        attempts: store.challenge,
        progress: store.progress,
        momentum: store.momentum,
        commits: store.challenge,
        rewardPolicy: RewardPolicy(const RewardPolicyConfig()),
        rankPolicy: DevelopmentRankConfig.policy(),
        idGenerator: idGenerator,
      ),
      clock: clock,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      onActiveChanged: feed.setActiveChallenge,
      onProjectionChanged: () => runtime.refreshAfterChallengeAction(),
    );
    runtime = VNextRuntime._(
      store: store,
      bundled: bundled,
      featureFlags: featureFlags,
      onboarding: onboarding,
      feed: feed,
      feedChallenge: feedChallenge,
      journey: journey,
      settings: settings,
      artifacts: artifacts,
    );
    return runtime;
  }

  VNextRuntime._({
    required this.store,
    required this.bundled,
    required this.featureFlags,
    required this.onboarding,
    required this.feed,
    required this.feedChallenge,
    required this.journey,
    required this.settings,
    required this.artifacts,
  });

  final SqliteVNextStore store;
  final BundledVNextContent bundled;
  final FeatureFlagRuntime featureFlags;
  final OnboardingController onboarding;
  final FeedViewController feed;
  final FeedChallengeController feedChallenge;
  final JourneyController journey;
  final SettingsController settings;
  final ArtifactOwnershipController artifacts;

  LocalIdentity? _identity;
  String? _pendingRankUp;

  LocalIdentity get identity =>
      _identity ?? (throw StateError('vNext identity is not initialized'));

  String? get pendingRankUp => _pendingRankUp;

  String get anonymousHandle {
    final compact = identity.localUserId
        .replaceAll(RegExp('[^A-Za-z0-9]'), '')
        .toUpperCase();
    final suffix = compact.length >= 6
        ? compact.substring(0, 6)
        : compact.padRight(6, '0');
    return 'MAYHEM-$suffix';
  }

  Future<void> initialize({
    required bool legacyUserHasProgress,
    required bool legacySafetyAccepted,
  }) async {
    await Future.wait([
      settings.initialize(),
      onboarding.initialize(
        legacyUserHasProgress: legacyUserHasProgress,
        legacySafetyAccepted: legacySafetyAccepted,
      ),
    ]);
    _identity = await store.identity.loadIdentity();
    if (onboarding.progress.isComplete) await loadProduct();
  }

  Future<void> loadProduct() async {
    await Future.wait([
      feed.initialize(),
      journey.initialize(),
      artifacts.initialize(),
    ]);
    final feedSnapshot = feed.snapshot;
    if (feedSnapshot != null) feedChallenge.initialize(feedSnapshot);
    await _detectRankUp();
  }

  Future<void> refreshAfterChallengeAction() async {
    await journey.initialize();
    await _detectRankUp();
  }

  Future<void> refreshAfterRemoteSync() async {
    await Future.wait([journey.initialize(), artifacts.initialize()]);
    await _detectRankUp();
  }

  Future<void> _detectRankUp() async {
    final rankLabel = journey.snapshot?.projection.rank.label;
    if (rankLabel == null) return;
    final previous = await store.metadata.read(_lastSeenRankKey);
    if (previous == null) {
      await store.metadata.write(_lastSeenRankKey, rankLabel);
    } else if (previous != rankLabel) {
      if (_pendingRankUp != rankLabel) {
        _pendingRankUp = rankLabel;
        notifyListeners();
      }
    }
  }

  Future<void> consumeRankUp() async {
    final rankLabel = _pendingRankUp;
    if (rankLabel == null) return;
    await store.metadata.write(_lastSeenRankKey, rankLabel);
    _pendingRankUp = null;
    notifyListeners();
  }

  Future<void> reinitializeAfterLocalReset() async {
    _pendingRankUp = null;
    _identity = await store.identity.loadIdentity();
    await Future.wait([
      settings.initialize(),
      onboarding.initialize(
        legacyUserHasProgress: false,
        legacySafetyAccepted: false,
      ),
    ]);
    notifyListeners();
  }
}
