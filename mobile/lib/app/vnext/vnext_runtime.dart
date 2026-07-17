import 'package:flutter/foundation.dart';

import '../../content/data/bundled_vnext_content_adapter.dart';
import '../../core/clock/mayhem_clock.dart';
import '../../core/feature_flags/feature_flag_runtime.dart';
import '../../core/feature_flags/feature_flags.dart';
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
import '../../features/season/application/season_experience_controller.dart';
import '../../features/season/application/season_participation_coordinator.dart';
import '../../features/settings/application/remote_account_controller.dart';
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
        remoteFeedEnabled: () =>
            featureFlags.isEnabled(MayhemFeatureFlag.newFeedEnabled),
        remoteContentEnabled: () =>
            featureFlags.isEnabled(MayhemFeatureFlag.remoteContentEnabled),
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
    final seasonParticipation = SeasonParticipationCoordinator(
      packages: store.season,
      participation: store.seasonParticipation,
      eventIdGenerator: idGenerator,
      clock: clock.utcNow,
      timezoneId: clock.timezoneId,
      timezoneOffsetMinutes:
          timezoneOffsetMinutes?.call() ??
          clock.localNow().timeZoneOffset.inMinutes,
      onTerminalAction: () => runtime._terminalSyncTrigger?.call(),
    );
    final season = SeasonExperienceController(
      packages: store.season,
      participation: store.seasonParticipation,
      ownership: store.reconciliation,
      actions: store.seasonActions,
      actionStager: seasonParticipation,
      enabled: () =>
          featureFlags.isEnabled(MayhemFeatureFlag.seasonZeroEnabled),
      clock: clock.utcNow,
    );
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
      season: season,
      seasonParticipation: seasonParticipation,
    );
    featureFlags.addListener(runtime._handleFeatureFlagsChanged);
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
    required this.season,
    required this.seasonParticipation,
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
  final SeasonExperienceController season;
  final SeasonParticipationCoordinator seasonParticipation;

  LocalIdentity? _identity;
  String? _pendingRankUp;
  RemoteAccountController? _remoteAccount;
  void Function()? _terminalSyncTrigger;

  RemoteAccountController? get remoteAccount => _remoteAccount;

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
      season.initialize(),
    ]);
    final feedSnapshot = feed.snapshot;
    if (feedSnapshot != null) feedChallenge.initialize(feedSnapshot);
    await _detectRankUp();
  }

  Future<void> refreshAfterChallengeAction() async {
    await journey.initialize();
    await _detectRankUp();
    _terminalSyncTrigger?.call();
  }

  Future<void> refreshAfterRemoteSync() async {
    await Future.wait([
      journey.initialize(),
      artifacts.initialize(),
      season.initialize(),
    ]);
    await _detectRankUp();
  }

  Future<void> refreshAfterRemoteFeed() async {
    await feed.initialize();
    final snapshot = feed.snapshot;
    if (snapshot != null) feedChallenge.initialize(snapshot);
  }

  void attachRemote({
    required RemoteAccountController account,
    required void Function() onTerminalSync,
    required Future<bool> Function() synchronizeSeasonAction,
  }) {
    if (_remoteAccount != null) {
      throw StateError('Remote runtime is already attached');
    }
    _remoteAccount = account;
    _terminalSyncTrigger = onTerminalSync;
    season.attachRemote(synchronize: synchronizeSeasonAction);
  }

  Future<void> beginRemoteRefresh() => season.beginRemoteRefresh();

  Future<void> completeRemoteRefresh({required bool succeeded}) =>
      season.completeRemoteRefresh(succeeded: succeeded);

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

  void _handleFeatureFlagsChanged() {
    season.initialize();
    notifyListeners();
  }

  @override
  void dispose() {
    featureFlags.removeListener(_handleFeatureFlagsChanged);
    season.dispose();
    _remoteAccount?.dispose();
    super.dispose();
  }
}
