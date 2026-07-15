import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'mayhem_button.dart';
import 'mayhem_glass.dart';
import 'mayhem_text.dart';
import 'rank_sigil.dart';

class CompactRankUpScene extends StatelessWidget {
  const CompactRankUpScene({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.dismissLabel,
    required this.tier,
    required this.onDismiss,
  });

  final String eyebrow;
  final String title;
  final String dismissLabel;
  final RankSigilTier tier;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$eyebrow. $title',
      child: MayhemGlass(
        kind: MayhemGlassKind.sheet,
        borderRadius: MayhemRadii.large,
        padding: const EdgeInsets.all(MayhemSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MayhemText(eyebrow, variant: MayhemTextVariant.labelMicro),
            const SizedBox(height: MayhemSpacing.x3),
            RankSigil(tier: tier, size: 88, showLabel: false),
            const SizedBox(height: MayhemSpacing.x3),
            MayhemText(
              title,
              variant: MayhemTextVariant.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MayhemSpacing.x5),
            MayhemPrimaryButton(
              label: dismissLabel,
              onPressed: onDismiss,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }
}
