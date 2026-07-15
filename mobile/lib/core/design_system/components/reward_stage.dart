import 'package:flutter/material.dart';

import '../accessibility/mayhem_motion_preferences.dart';
import '../motion/mayhem_curves.dart';
import '../motion/mayhem_durations.dart';
import '../tokens/tokens.dart';
import 'mayhem_text.dart';
import 'momentum_core.dart';

enum RewardStageKind { attempt, completion }

class RewardStage extends StatelessWidget {
  const RewardStage({
    super.key,
    required this.kind,
    required this.playId,
    required this.xp,
    required this.traitLabel,
    required this.momentumDays,
    this.completionLabel = 'CHALLENGE COMPLETE',
    this.attemptLabel = 'ATTEMPT COUNTED',
  });

  final RewardStageKind kind;
  final Object playId;
  final int xp;
  final String traitLabel;
  final int momentumDays;
  final String completionLabel;
  final String attemptLabel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MayhemAccessibility.of(context).reduceMotion;
    final completed = kind == RewardStageKind.completion;
    return Semantics(
      container: true,
      liveRegion: true,
      label:
          '${completed ? completionLabel : attemptLabel}, '
          '$xp XP, $traitLabel',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(playId),
          tween: Tween(begin: 0, end: 1),
          duration: reduceMotion
              ? MayhemDurations.standard
              : MayhemDurations.ceremony,
          curve: MayhemCurves.emphasized,
          builder: (context, progress, child) {
            final coreScale = reduceMotion ? 1.0 : 0.82 + progress * 0.18;
            return DecoratedBox(
              decoration: const BoxDecoration(
                color: MayhemColors.canvasDeep,
                borderRadius: MayhemRadii.large,
                border: Border.fromBorderSide(
                  BorderSide(color: MayhemColors.lineSubtle),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(MayhemSpacing.x6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: coreScale,
                      child: MomentumCore(
                        days: momentumDays,
                        state: completed
                            ? MomentumCoreState.earned
                            : MomentumCoreState.available,
                        size: 112,
                      ),
                    ),
                    const SizedBox(height: MayhemSpacing.x5),
                    MayhemText(
                      completed ? completionLabel : attemptLabel,
                      variant: MayhemTextVariant.labelMicro,
                      color: completed
                          ? MayhemColors.semanticSuccess
                          : MayhemColors.semanticInfo,
                    ),
                    const SizedBox(height: MayhemSpacing.x3),
                    MayhemText(
                      '+$xp XP',
                      variant: MayhemTextVariant.numberStatus,
                    ),
                    const SizedBox(height: MayhemSpacing.x2),
                    MayhemText(
                      traitLabel,
                      variant: MayhemTextVariant.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
