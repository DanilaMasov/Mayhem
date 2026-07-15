import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/core/feature_flags/remote_feature_flag_resolver.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

void main() {
  test(
    'remote true is accepted only with the required capability revision',
    () {
      final record = RemoteFlagRecord(
        flag: MayhemFeatureFlag.remoteContentEnabled,
        enabled: true,
        requiredCapabilityKey: 'remote_content',
        requiredCapabilityRevision: 2,
        updatedAt: DateTime.utc(2026, 7, 13),
      );

      final unsupported = RemoteFeatureFlagResolver.resolve(
        records: [record],
        capabilities: CapabilityRevisionSet(const {'remote_content': 1}),
      );
      final supported = RemoteFeatureFlagResolver.resolve(
        records: [record],
        capabilities: CapabilityRevisionSet(const {'remote_content': 2}),
      );

      expect(
        unsupported.isEnabled(MayhemFeatureFlag.remoteContentEnabled),
        isFalse,
      );
      expect(
        supported.isEnabled(MayhemFeatureFlag.remoteContentEnabled),
        isTrue,
      );
      expect(
        supported.isEnabled(MayhemFeatureFlag.accountLinkingEnabled),
        isFalse,
      );
    },
  );

  test('malformed or unknown bootstrap flags are ignored fail-closed', () {
    final payload = _bootstrapJson()
      ..['flags'] = [
        {
          'key': 'future_unknown_flag',
          'enabled': true,
          'updatedAt': '2026-07-13T12:00:00.000Z',
        },
        {
          'key': 'remote_content_enabled',
          'enabled': 'yes',
          'updatedAt': '2026-07-13T12:00:00.000Z',
        },
      ];

    final parsed = BootstrapPayload.fromJson(payload);
    final resolved = RemoteFeatureFlagResolver.resolve(
      records: parsed.flags,
      capabilities: CapabilityRevisionSet(const {'remote_content': 99}),
    );

    expect(parsed.flags, isEmpty);
    expect(resolved.isEnabled(MayhemFeatureFlag.remoteContentEnabled), isFalse);
  });

  test('missing capabilities and duplicate records resolve to false', () {
    final withoutCapability = RemoteFlagRecord(
      flag: MayhemFeatureFlag.accountLinkingEnabled,
      enabled: true,
      updatedAt: DateTime.utc(2026, 7, 13),
    );
    final remoteContent = RemoteFlagRecord(
      flag: MayhemFeatureFlag.remoteContentEnabled,
      enabled: true,
      requiredCapabilityKey: 'remote_content',
      requiredCapabilityRevision: 1,
      updatedAt: DateTime.utc(2026, 7, 13),
    );
    final resolved = RemoteFeatureFlagResolver.resolve(
      records: [withoutCapability, remoteContent, remoteContent],
      capabilities: CapabilityRevisionSet(const {'remote_content': 1}),
    );

    expect(
      resolved.isEnabled(MayhemFeatureFlag.accountLinkingEnabled),
      isFalse,
    );
    expect(resolved.isEnabled(MayhemFeatureFlag.remoteContentEnabled), isFalse);
  });

  test('structurally malformed flag collection leaves bootstrap usable', () {
    final payload = _bootstrapJson()..['flags'] = {'enabled': true};

    final parsed = BootstrapPayload.fromJson(payload);

    expect(parsed.flags, isEmpty);
  });
}

Map<String, dynamic> _bootstrapJson() => {
  'identity': {
    'remoteUserId': 'remote-user',
    'localUserId': 'local-user',
    'installationId': 'installation-id',
  },
  'flags': <Object?>[],
  'projection': _projectionJson(),
  'contentManifest': {
    'manifestRevision': 0,
    'locale': 'ru',
    'generatedAt': '2026-07-13T12:00:00.000Z',
    'items': <Object?>[],
  },
  'serverTime': '2026-07-13T12:00:00.000Z',
};

Map<String, dynamic> _projectionJson() => {
  'totalXp': 0,
  'traitXp': {'initiation': 0, 'expression': 0, 'connection': 0, 'presence': 0},
  'rank': {
    'family': 'spark',
    'tier': 1,
    'configRevision': 'rank_config_dev_v1',
  },
  'rewardPolicyRevision': 'reward_policy_dev_v1',
  'completedCount': 0,
  'attemptedCount': 0,
  'projectionRevision': 0,
  'updatedAt': '2026-07-13T12:00:00.000Z',
  'difficulty': <String, Object?>{},
  'momentum': {
    'currentDays': 0,
    'longestDays': 0,
    'shieldsAvailable': 0,
    'protectedLocalDates': <String>[],
    'policyRevision': 'momentum_policy_dev_v1',
    'projectionRevision': 0,
  },
};
