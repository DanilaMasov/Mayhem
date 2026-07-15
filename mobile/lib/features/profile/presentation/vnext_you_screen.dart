import 'package:flutter/material.dart';

import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../../progress/application/journey_controller.dart';
import '../../progress/domain/progress_models.dart';
import '../../progress/presentation/vnext_journey_screen.dart';
import '../../season/application/artifact_ownership_controller.dart';
import '../../settings/presentation/vnext_settings_screen.dart';

class VNextYouScreen extends StatelessWidget {
  const VNextYouScreen({
    super.key,
    required this.anonymousHandle,
    required this.journey,
    required this.artifacts,
    required this.artifactsEnabled,
  });

  final String anonymousHandle;
  final JourneyController journey;
  final ArtifactOwnershipController artifacts;
  final bool artifactsEnabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([journey, artifacts]),
      builder: (context, child) {
        final snapshot = journey.snapshot;
        if (journey.loading || snapshot == null) {
          return Center(
            child: MayhemText(
              context.strings.loading,
              variant: MayhemTextVariant.bodyLarge,
            ),
          );
        }
        return _YouContent(
          anonymousHandle: anonymousHandle,
          snapshot: snapshot,
          artifacts: artifactsEnabled ? artifacts.artifacts : const [],
        );
      },
    );
  }
}

class _YouContent extends StatelessWidget {
  const _YouContent({
    required this.anonymousHandle,
    required this.snapshot,
    required this.artifacts,
  });

  final String anonymousHandle;
  final JourneySnapshot snapshot;
  final List<PresentedFounderArtifact> artifacts;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final rank = snapshot.projection.rank;
    final strongest = strongestTrait(snapshot.projection.traitXp);
    final sigilTier = rank.family == RankFamily.spark
        ? RankSigilTier.spark
        : RankSigilTier.mover;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const PageStorageKey('you-scroll'),
        padding: const EdgeInsets.only(bottom: 132),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MayhemSpacing.x5,
              MayhemSpacing.x3,
              MayhemSpacing.x3,
              MayhemSpacing.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: MayhemText(
                    strings.youTitle,
                    variant: MayhemTextVariant.labelMicro,
                  ),
                ),
                IconButton(
                  tooltip: strings.settings,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(YouRoutes.settings),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 360),
            color: MayhemColors.canvasRaised,
            padding: const EdgeInsets.all(MayhemSpacing.x6),
            child: Column(
              children: [
                MayhemText(
                  strings.anonymousLocalProfile,
                  variant: MayhemTextVariant.labelMicro,
                ),
                const SizedBox(height: MayhemSpacing.x3),
                MayhemText(
                  anonymousHandle,
                  variant: MayhemTextVariant.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MayhemSpacing.x5),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          RankSigil(
                            tier: sigilTier,
                            size: 118,
                            showLabel: false,
                          ),
                          const SizedBox(height: MayhemSpacing.x2),
                          MayhemText(
                            rank.label,
                            variant: MayhemTextVariant.labelLarge,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: MomentumCore(
                        days: snapshot.momentum.currentDays,
                        state: momentumCoreState(snapshot.momentum),
                        size: 128,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MayhemSpacing.x5),
                MayhemText(
                  strings.strongestTrait(strings.traitName(strongest)),
                  variant: MayhemTextVariant.bodyMedium,
                  color: MayhemColors.textPrimary,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (artifacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(MayhemSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MayhemText(
                    strings.seasonArtifact,
                    variant: MayhemTextVariant.labelLarge,
                  ),
                  const SizedBox(height: MayhemSpacing.x4),
                  for (final artifact in artifacts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MayhemSpacing.x3),
                      child: _OwnedArtifactTile(artifact: artifact),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OwnedArtifactTile extends StatelessWidget {
  const _OwnedArtifactTile({required this.artifact});

  final PresentedFounderArtifact artifact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: MayhemColors.surfaceBase,
      borderRadius: MayhemRadii.medium,
      border: Border.all(color: MayhemColors.semanticSuccess),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 88),
      child: Padding(
        padding: const EdgeInsets.all(MayhemSpacing.x4),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: MayhemColors.semanticSuccess,
              size: 32,
            ),
            const SizedBox(width: MayhemSpacing.x4),
            Expanded(
              child: MayhemText(
                artifact.title,
                variant: MayhemTextVariant.labelLarge,
                color: MayhemColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
