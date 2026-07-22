import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/accessibility/mayhem_motion_preferences.dart';
import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../domain/progress_models.dart';
import 'rank_visual_identity.dart';

class RankPromotionScene extends StatefulWidget {
  const RankPromotionScene({
    super.key,
    required this.previousRank,
    required this.currentRank,
    required this.ratingScore,
    required this.ratingDelta,
    required this.onDismiss,
  });

  final PrestigeRank previousRank;
  final PrestigeRank currentRank;
  final int ratingScore;
  final int ratingDelta;
  final VoidCallback onDismiss;

  @override
  State<RankPromotionScene> createState() => _RankPromotionSceneState();
}

class _RankPromotionSceneState extends State<RankPromotionScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MayhemAccessibility.of(context).reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final accent = rankFamilyColor(widget.currentRank.family);
    final semanticLabel = [
      strings.rankUp,
      strings.rankUnlocked(widget.currentRank.label),
      strings.currentRating(widget.ratingScore),
    ].join('. ');
    return Semantics(
      key: const ValueKey('rank-promotion-overlay'),
      container: true,
      scopesRoute: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: semanticLabel,
      child: Material(
        color: MayhemColors.overlayDeep,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _PromotionFieldPainter(
                      progress: progress,
                      accent: accent,
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 720;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MayhemSpacing.x5,
                          vertical: MayhemSpacing.x4,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - MayhemSpacing.x8,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: _PromotionContent(
                                progress: progress,
                                compact: compact,
                                accent: accent,
                                previousRank: widget.previousRank,
                                currentRank: widget.currentRank,
                                ratingScore: widget.ratingScore,
                                ratingDelta: widget.ratingDelta,
                                onDismiss: widget.onDismiss,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PromotionContent extends StatelessWidget {
  const _PromotionContent({
    required this.progress,
    required this.compact,
    required this.accent,
    required this.previousRank,
    required this.currentRank,
    required this.ratingScore,
    required this.ratingDelta,
    required this.onDismiss,
  });

  final double progress;
  final bool compact;
  final Color accent;
  final PrestigeRank previousRank;
  final PrestigeRank currentRank;
  final int ratingScore;
  final int ratingDelta;
  final VoidCallback onDismiss;

  double _interval(double begin, double end, {Curve curve = Curves.easeOut}) =>
      curve.transform(((progress - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final intro = _interval(0.02, 0.2);
    final oldExit = 1 - _interval(0.18, 0.34, curve: Curves.easeIn);
    final badge = _interval(0.2, 0.55, curve: Curves.elasticOut);
    final title = _interval(0.4, 0.64, curve: Curves.easeOutCubic);
    final rating = _interval(0.55, 0.76, curve: Curves.easeOutBack);
    final actions = _interval(0.72, 0.9, curve: Curves.easeOut);
    final badgeSize = compact ? 152.0 : 184.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: intro,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - intro)),
            child: MayhemText(
              strings.rankUp,
              variant: MayhemTextVariant.labelMicro,
              color: accent,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(height: compact ? MayhemSpacing.x3 : MayhemSpacing.x5),
        Opacity(
          opacity: oldExit,
          child: Transform.translate(
            offset: Offset(0, -14 * (1 - oldExit)),
            child: MayhemText(
              strings.rankPrevious(previousRank.label),
              variant: MayhemTextVariant.bodySmall,
              color: MayhemColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(height: compact ? MayhemSpacing.x2 : MayhemSpacing.x4),
        Transform.rotate(
          angle: (1 - badge) * -0.18,
          child: Transform.scale(
            key: const ValueKey('rank-promotion-badge'),
            scale: badge,
            child: _PromotionBadge(
              family: currentRank.family,
              accent: accent,
              size: badgeSize,
              pulse: _interval(0.48, 1, curve: Curves.easeInOut),
            ),
          ),
        ),
        SizedBox(height: compact ? MayhemSpacing.x3 : MayhemSpacing.x5),
        Opacity(
          opacity: title,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - title)),
            child: Column(
              children: [
                MayhemText(
                  strings.rankUnlocked(currentRank.label),
                  key: const ValueKey('rank-promotion-title'),
                  variant: MayhemTextVariant.headlineLarge,
                  color: MayhemColors.textPrimary,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
                const SizedBox(height: MayhemSpacing.x2),
                Container(
                  width: 72,
                  height: 2,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: MayhemRadii.pill,
                    boxShadow: [BoxShadow(color: accent, blurRadius: 12)],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MayhemSpacing.x5),
        Opacity(
          opacity: rating,
          child: Transform.scale(
            scale: 0.9 + rating * 0.1,
            child: Wrap(
              key: const ValueKey('rank-promotion-rating'),
              alignment: WrapAlignment.center,
              spacing: MayhemSpacing.x2,
              runSpacing: MayhemSpacing.x2,
              children: [
                _RatingPill(
                  label: strings.rankRatingGain(ratingDelta),
                  accent: accent,
                  emphasized: true,
                ),
                _RatingPill(
                  label: strings.currentRating(ratingScore),
                  accent: accent,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MayhemSpacing.x4),
        Opacity(
          opacity: actions,
          child: MayhemText(
            strings.rankPromotionBody,
            variant: MayhemTextVariant.bodySmall,
            color: MayhemColors.textSecondary,
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
        ),
        SizedBox(height: compact ? MayhemSpacing.x4 : MayhemSpacing.x6),
        IgnorePointer(
          ignoring: actions < 0.99,
          child: Opacity(
            opacity: actions,
            child: MayhemPrimaryButton(
              key: const ValueKey('rank-promotion-continue'),
              label: strings.continueLabel,
              onPressed: onDismiss,
              expand: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromotionBadge extends StatelessWidget {
  const _PromotionBadge({
    required this.family,
    required this.accent,
    required this.size,
    required this.pulse,
  });

  final RankFamily family;
  final Color accent;
  final double size;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * (0.78 + pulse * 0.12),
            height: size * (0.78 + pulse * 0.12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
          ),
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.32),
                  MayhemColors.surfaceHigh,
                  MayhemColors.canvasDeep,
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.42),
                  blurRadius: 40 + pulse * 14,
                  spreadRadius: 2 + pulse * 3,
                ),
              ],
            ),
            child: Icon(
              rankFamilyIcon(family),
              color: MayhemColors.textPrimary,
              size: size * 0.31,
            ),
          ),
          for (var index = 0; index < 4; index += 1)
            Transform.rotate(
              angle: math.pi / 4 + index * math.pi / 2,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 2,
                  height: size * 0.13,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({
    required this.label,
    required this.accent,
    this.emphasized = false,
  });

  final String label;
  final Color accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasized ? 0.2 : 0.08),
        borderRadius: MayhemRadii.pill,
        border: Border.all(
          color: accent.withValues(alpha: emphasized ? 0.85 : 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MayhemSpacing.x3,
          vertical: MayhemSpacing.x2,
        ),
        child: MayhemText(
          label,
          variant: MayhemTextVariant.labelLarge,
          color: emphasized ? accent : MayhemColors.textPrimary,
        ),
      ),
    );
  }
}

class _PromotionFieldPainter extends CustomPainter {
  const _PromotionFieldPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final reveal = Curves.easeOut.transform((progress / 0.7).clamp(0.0, 1.0));
    final background = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.2 * reveal),
          MayhemColors.overlayDeep.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.longestSide));
    canvas.drawRect(Offset.zero & size, background);

    final rayPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;
    for (var index = 0; index < 18; index += 1) {
      final angle = index * math.pi * 2 / 18 + progress * 0.22;
      final length = size.shortestSide * (0.32 + (index % 4) * 0.045);
      rayPaint.color = accent.withValues(
        alpha: (0.035 + (index.isEven ? 0.035 : 0)) * reveal,
      );
      canvas.drawLine(
        center + Offset.fromDirection(angle, 86),
        center + Offset.fromDirection(angle, length),
        rayPaint,
      );
    }

    final particleProgress = Curves.easeOutCubic.transform(
      ((progress - 0.12) / 0.72).clamp(0.0, 1.0),
    );
    for (var index = 0; index < 32; index += 1) {
      final seed = (index * 47 % 101) / 101;
      final angle = index * 2.399963 + seed * 0.5;
      final distance =
          (54 + seed * size.shortestSide * 0.56) * particleProgress;
      final point = center + Offset.fromDirection(angle, distance);
      final fade = (1 - (particleProgress - 0.72).clamp(0.0, 0.28) / 0.28)
          .clamp(0.0, 1.0);
      canvas.drawCircle(
        point,
        1.2 + (index % 3) * 0.7,
        Paint()
          ..color = (index % 4 == 0 ? MayhemColors.textPrimary : accent)
              .withValues(alpha: (0.25 + seed * 0.55) * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_PromotionFieldPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
