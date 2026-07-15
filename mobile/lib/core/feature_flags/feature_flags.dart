enum MayhemFeatureFlag {
  newFeedEnabled,
  remoteContentEnabled,
  seasonZeroEnabled,
  bossRaidEnabled,
  socialProofEnabled,
  accountLinkingEnabled,
  companionEnabled,
  advancedMotionEnabled,
  rankShareEnabled,
  notificationsEnabled,
}

extension MayhemFeatureFlagWire on MayhemFeatureFlag {
  String get wireName => switch (this) {
    MayhemFeatureFlag.newFeedEnabled => 'new_feed_enabled',
    MayhemFeatureFlag.remoteContentEnabled => 'remote_content_enabled',
    MayhemFeatureFlag.seasonZeroEnabled => 'season_zero_enabled',
    MayhemFeatureFlag.bossRaidEnabled => 'boss_raid_enabled',
    MayhemFeatureFlag.socialProofEnabled => 'social_proof_enabled',
    MayhemFeatureFlag.accountLinkingEnabled => 'account_linking_enabled',
    MayhemFeatureFlag.companionEnabled => 'companion_enabled',
    MayhemFeatureFlag.advancedMotionEnabled => 'advanced_motion_enabled',
    MayhemFeatureFlag.rankShareEnabled => 'rank_share_enabled',
    MayhemFeatureFlag.notificationsEnabled => 'notifications_enabled',
  };
}

class FeatureFlagSnapshot {
  FeatureFlagSnapshot({Map<MayhemFeatureFlag, bool> values = const {}})
    : values = Map.unmodifiable(values);

  factory FeatureFlagSnapshot.safeDefaults() => FeatureFlagSnapshot();

  final Map<MayhemFeatureFlag, bool> values;

  bool isEnabled(MayhemFeatureFlag flag) => values[flag] ?? false;
}
