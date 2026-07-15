import 'package:flutter/material.dart';

import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/feature_flags/feature_flag_runtime.dart';
import '../../../core/feature_flags/feature_flags.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../../../app/composition/remote_runtime_diagnostics.dart';
import '../../challenge/domain/reward_policy.dart';
import '../../onboarding/domain/onboarding_models.dart';
import '../../progress/domain/development_rank_config.dart';
import '../../progress/domain/difficulty_update_policy.dart';
import '../../streak/domain/momentum_policy.dart';
import '../../sync/application/vnext_sync_coordinator.dart';
import '../application/remote_account_controller.dart';
import '../application/settings_controller.dart';

abstract final class YouRoutes {
  static const root = '/you';
  static const settings = '/you/settings';
  static const diagnostics = '/you/settings/diagnostics';
  static const privacy = '/you/privacy';
  static const accessibility = '/you/accessibility';
  static const account = '/you/account';
}

class VNextSettingsScreen extends StatefulWidget {
  const VNextSettingsScreen({
    super.key,
    required this.controller,
    required this.featureFlags,
    required this.onResetLocalData,
    this.remoteAccount,
  });

  final SettingsController controller;
  final FeatureFlagRuntime featureFlags;
  final Future<void> Function() onResetLocalData;
  final RemoteAccountController? remoteAccount;

  @override
  State<VNextSettingsScreen> createState() => _VNextSettingsScreenState();
}

class _VNextSettingsScreenState extends State<VNextSettingsScreen> {
  bool _resetting = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settingsTitle),
        leading: IconButton(
          tooltip: strings.back,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.controller, ?widget.remoteAccount]),
        builder: (context, child) {
          final preferences = widget.controller.preferences;
          return ListView(
            key: const PageStorageKey('settings-scroll'),
            padding: const EdgeInsets.fromLTRB(
              MayhemSpacing.x5,
              MayhemSpacing.x3,
              MayhemSpacing.x5,
              132,
            ),
            children: [
              _SectionTitle(strings.account),
              _StatusLine(
                icon: Icons.person_outline,
                title: strings.anonymousLocalProfile,
                body: widget.remoteAccount?.sessionAvailable == true
                    ? strings.cloudSessionActive
                    : strings.localOnlyStatus,
              ),
              const _SectionDivider(),
              _SectionTitle(strings.accessibility),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.reduceMotion),
                subtitle: Text(strings.reduceMotionBody),
                value: preferences.reduceMotion,
                onChanged: (value) => widget.controller.update(
                  preferences.copyWith(reduceMotion: value),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.reduceTransparency),
                subtitle: Text(strings.reduceTransparencyBody),
                value: preferences.reduceTransparency,
                onChanged: (value) => widget.controller.update(
                  preferences.copyWith(reduceTransparency: value),
                ),
              ),
              const _SectionDivider(),
              _SectionTitle(strings.feedback),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.haptics),
                value: preferences.hapticsEnabled,
                onChanged: (value) => widget.controller.update(
                  preferences.copyWith(hapticsEnabled: value),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.sound),
                value: preferences.soundEnabled,
                onChanged: (value) => widget.controller.update(
                  preferences.copyWith(soundEnabled: value),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.ceremonies),
                value: preferences.ceremoniesEnabled,
                onChanged: (value) => widget.controller.update(
                  preferences.copyWith(ceremoniesEnabled: value),
                ),
              ),
              const _SectionDivider(),
              _SectionTitle(strings.notifications),
              _StatusLine(
                icon: Icons.notifications_off_outlined,
                title: strings.disabled,
                body: strings.notificationsUnavailable,
              ),
              const _SectionDivider(),
              _SectionTitle(strings.privacy),
              MayhemText(
                strings.privacyBody,
                variant: MayhemTextVariant.bodyMedium,
              ),
              const SizedBox(height: MayhemSpacing.x3),
              MayhemText(
                strings.privateNotesStatus,
                variant: MayhemTextVariant.bodySmall,
              ),
              const _SectionDivider(),
              _SectionTitle(strings.language),
              _StatusLine(
                icon: Icons.language_outlined,
                title: strings.russian,
                body: 'ru-RU',
              ),
              const _SectionDivider(),
              _SectionTitle(strings.dataAndSync),
              MayhemText(
                widget.remoteAccount?.sessionAvailable == true
                    ? strings.cloudSessionActive
                    : strings.localOnlyStatus,
                variant: MayhemTextVariant.bodyMedium,
              ),
              if (widget.remoteAccount case final account?) ...[
                const SizedBox(height: MayhemSpacing.x3),
                MayhemSecondaryButton(
                  label: strings.retry,
                  icon: MayhemGlyph.refresh,
                  onPressed: account.busy ? null : _retryRemoteSync,
                  loading: account.status == RemoteAccountStatus.syncing,
                ),
              ],
              const SizedBox(height: MayhemSpacing.x5),
              MayhemSecondaryButton(
                label: strings.resetOnDevice,
                icon: MayhemGlyph.refresh,
                onPressed: _resetting ? null : _confirmReset,
                loading: _resetting,
              ),
              const SizedBox(height: MayhemSpacing.x2),
              MayhemText(
                strings.resetOnDeviceBody,
                variant: MayhemTextVariant.bodySmall,
              ),
              const SizedBox(height: MayhemSpacing.x5),
              MayhemSecondaryButton(
                label: strings.deleteEverywhere,
                onPressed: widget.remoteAccount?.canDeleteEverywhere == true
                    ? _confirmDeleteEverywhere
                    : null,
                enabled: widget.remoteAccount?.canDeleteEverywhere == true,
                loading:
                    widget.remoteAccount?.status ==
                    RemoteAccountStatus.deleting,
              ),
              const SizedBox(height: MayhemSpacing.x2),
              MayhemText(
                widget.remoteAccount?.canDeleteEverywhere == true
                    ? strings.deleteEverywhereAvailable
                    : strings.deleteEverywhereUnavailable,
                variant: MayhemTextVariant.bodySmall,
              ),
              const _SectionDivider(),
              _SectionTitle(strings.safetyResources),
              MayhemText(
                strings.safetyResourcesBody,
                variant: MayhemTextVariant.bodyMedium,
              ),
              const _SectionDivider(),
              _SectionTitle(strings.about),
              MayhemText(
                strings.aboutBody,
                variant: MayhemTextVariant.bodyMedium,
              ),
              const SizedBox(height: MayhemSpacing.x5),
              MayhemSecondaryButton(
                label: strings.diagnostics,
                onPressed: () =>
                    Navigator.of(context).pushNamed(YouRoutes.diagnostics),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset() async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.confirmResetTitle),
        content: Text(strings.confirmResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      await widget.onResetLocalData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.resetFailed)));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _retryRemoteSync() async {
    final result = await widget.remoteAccount?.retrySync();
    if (!mounted || result?.status != SyncRunStatus.failed) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.remoteSyncFailed)));
  }

  Future<void> _confirmDeleteEverywhere() async {
    final account = widget.remoteAccount;
    if (account == null || !account.canDeleteEverywhere) return;
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.confirmDeleteEverywhereTitle),
        content: Text(strings.confirmDeleteEverywhereBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.deleteEverywhereConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await account.deleteEverywhere();
    if (!mounted || deleted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          account.deletionRecoveryPending
              ? strings.deleteEverywhereRecoveryRequired
              : strings.deleteEverywhereFailed,
        ),
      ),
    );
  }
}

class VNextDiagnosticsScreen extends StatelessWidget {
  const VNextDiagnosticsScreen({
    super.key,
    required this.featureFlags,
    this.remoteDiagnostics,
    this.remoteAccount,
  });

  final FeatureFlagRuntime featureFlags;
  final RemoteRuntimeDiagnostics? remoteDiagnostics;
  final RemoteAccountDiagnostics? remoteAccount;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    const reward = RewardPolicyConfig();
    const difficulty = DifficultyUpdatePolicy();
    return AnimatedBuilder(
      animation: Listenable.merge([
        featureFlags,
        ?remoteDiagnostics,
        ?remoteAccount,
      ]),
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: Text(strings.diagnosticsTitle),
          leading: IconButton(
            tooltip: strings.back,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(MayhemSpacing.x5),
          children: [
            _SectionTitle(strings.featureFlags),
            const SizedBox(height: MayhemSpacing.x3),
            for (final flag in MayhemFeatureFlag.values)
              _DiagnosticRow(
                label: flag.wireName,
                value: featureFlags.isEnabled(flag)
                    ? strings.enabled
                    : strings.disabled,
                detail: featureFlags.isDebugOverride(flag)
                    ? strings.debugOverride
                    : strings.productionDefault,
              ),
            const _SectionDivider(),
            _SectionTitle(strings.capabilityRevisions),
            const SizedBox(height: MayhemSpacing.x3),
            const _DiagnosticRow(
              label: 'calibration',
              value: CalibrationPolicy.revision,
            ),
            const _DiagnosticRow(label: 'safety', value: 'safety_revision_1'),
            _DiagnosticRow(label: 'reward', value: reward.revision),
            _DiagnosticRow(
              label: 'difficulty',
              value: difficulty.algorithmRevision,
            ),
            const _DiagnosticRow(
              label: 'rank',
              value: DevelopmentRankConfig.revision,
            ),
            const _DiagnosticRow(
              label: 'momentum',
              value: MomentumPolicy.revision,
            ),
            const _SectionDivider(),
            _SectionTitle(strings.environment),
            const SizedBox(height: MayhemSpacing.x3),
            _DiagnosticRow(
              label: 'remote.config',
              value: remoteDiagnostics?.remoteConfigured == true
                  ? 'configured'
                  : 'disabled',
            ),
            _DiagnosticRow(
              label: 'remote.runtime',
              value:
                  remoteDiagnostics?.remoteStatus.name ??
                  AppRemoteRuntimeStatus.disabled.name,
            ),
            _DiagnosticRow(
              label: 'remote.account',
              value:
                  remoteAccount?.status.name ??
                  RemoteAccountStatus.unavailable.name,
            ),
            _DiagnosticRow(
              label: 'remote.session',
              value: remoteAccount?.sessionAvailable == true
                  ? 'available'
                  : 'unavailable',
            ),
            if (remoteDiagnostics?.remoteErrorCode case final errorCode?)
              _DiagnosticRow(label: 'remote.error', value: errorCode),
            if (remoteAccount?.errorCode case final accountErrorCode?)
              _DiagnosticRow(
                label: 'remote.account_error',
                value: accountErrorCode,
              ),
            _DiagnosticRow(label: strings.devicePerformanceOpen, value: 'open'),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => MayhemText(
    label,
    variant: MayhemTextVariant.labelMicro,
    color: MayhemColors.brandSignalSoft,
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: MayhemSpacing.x6),
    child: Divider(color: MayhemColors.lineSubtle),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MayhemSpacing.x3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: MayhemColors.textSecondary),
        const SizedBox(width: MayhemSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MayhemText(
                title,
                variant: MayhemTextVariant.labelLarge,
                color: MayhemColors.textPrimary,
              ),
              const SizedBox(height: MayhemSpacing.x1),
              MayhemText(body, variant: MayhemTextVariant.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: MayhemSpacing.x2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MayhemText(label, variant: MayhemTextVariant.bodySmall),
        ),
        const SizedBox(width: MayhemSpacing.x3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MayhemText(
              value,
              variant: MayhemTextVariant.labelMedium,
              color: MayhemColors.textPrimary,
            ),
            if (detail != null)
              MayhemText(detail!, variant: MayhemTextVariant.labelMicro),
          ],
        ),
      ],
    ),
  );
}
