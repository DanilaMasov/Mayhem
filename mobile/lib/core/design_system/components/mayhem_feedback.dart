import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'mayhem_button.dart';
import 'mayhem_glass.dart';
import 'mayhem_text.dart';

class MayhemDialog extends StatelessWidget {
  const MayhemDialog({
    super.key,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: MayhemGlass(
          kind: MayhemGlassKind.sheet,
          padding: const EdgeInsets.all(MayhemSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MayhemText(title, variant: MayhemTextVariant.headlineSmall),
              const SizedBox(height: MayhemSpacing.x3),
              MayhemText(body, variant: MayhemTextVariant.bodyMedium),
              const SizedBox(height: MayhemSpacing.x6),
              MayhemPrimaryButton(label: primaryLabel, onPressed: onPrimary),
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: MayhemSpacing.x3),
                MayhemSecondaryButton(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MayhemToast extends StatelessWidget {
  const MayhemToast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: MayhemGlassControl(
        padding: const EdgeInsets.symmetric(
          horizontal: MayhemSpacing.x4,
          vertical: MayhemSpacing.x3,
        ),
        child: MayhemText(message, variant: MayhemTextVariant.bodySmall),
      ),
    );
  }
}

class MayhemLoadingState extends StatelessWidget {
  const MayhemLoadingState({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: MayhemSpacing.x12,
            height: MayhemSpacing.x1,
            decoration: const BoxDecoration(
              color: MayhemColors.brandSignalSoft,
              borderRadius: MayhemRadii.pill,
            ),
          ),
          const SizedBox(height: MayhemSpacing.x3),
          MayhemText(label, variant: MayhemTextVariant.bodySmall),
        ],
      ),
    );
  }
}

class MayhemErrorState extends StatelessWidget {
  const MayhemErrorState({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
  });

  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MayhemText(
            title,
            variant: MayhemTextVariant.headlineSmall,
            color: MayhemColors.semanticError,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MayhemSpacing.x2),
          MayhemText(message, textAlign: TextAlign.center),
          if (retryLabel != null && onRetry != null) ...[
            const SizedBox(height: MayhemSpacing.x5),
            MayhemSecondaryButton(
              label: retryLabel!,
              onPressed: onRetry,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}

class MayhemOfflineBadge extends StatelessWidget {
  const MayhemOfflineBadge({super.key, this.label = 'Offline'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label. Changes stay on this device.',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: MayhemColors.surfaceHigh,
          borderRadius: MayhemRadii.pill,
          border: Border.fromBorderSide(
            BorderSide(color: MayhemColors.semanticWarning),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MayhemSpacing.x3,
            vertical: MayhemSpacing.x2,
          ),
          child: MayhemText(
            label,
            variant: MayhemTextVariant.labelMedium,
            color: MayhemColors.semanticWarning,
          ),
        ),
      ),
    );
  }
}
