import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../accessibility/mayhem_motion_preferences.dart';
import '../motion/mayhem_springs.dart';
import '../tokens/tokens.dart';
import 'mayhem_text.dart';

enum FeedFixtureKind { challenge, training, scenario, season }

@immutable
class FeedFixtureItem {
  const FeedFixtureItem({
    required this.kind,
    required this.eyebrow,
    required this.statement,
    required this.detail,
    required this.energy,
  });

  final FeedFixtureKind kind;
  final String eyebrow;
  final String statement;
  final String detail;
  final Color energy;
}

class FeedPager extends StatefulWidget {
  const FeedPager({
    super.key,
    required this.items,
    this.controller,
    this.onPageChanged,
  });

  final List<FeedFixtureItem> items;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;

  @override
  State<FeedPager> createState() => _FeedPagerState();
}

class _FeedPagerState extends State<FeedPager> {
  late PageController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? PageController();
  }

  @override
  void didUpdateWidget(FeedPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    if (_ownsController) _controller.dispose();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? PageController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MayhemAccessibility.of(context).reduceMotion;
    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      physics: MayhemFeedScrollPhysics(reduceMotion: reduceMotion),
      itemCount: widget.items.length,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final page = _controller.hasClients
                ? (_controller.page ?? _controller.initialPage.toDouble())
                : _controller.initialPage.toDouble();
            final offset = (index - page).clamp(-1.0, 1.0);
            return _FeedScene(
              item: widget.items[index],
              position: index + 1,
              total: widget.items.length,
              pageOffset: reduceMotion ? 0 : offset,
            );
          },
        );
      },
    );
  }
}

class MayhemFeedScrollPhysics extends PageScrollPhysics {
  const MayhemFeedScrollPhysics({required this.reduceMotion, super.parent});

  final bool reduceMotion;

  @override
  MayhemFeedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return MayhemFeedScrollPhysics(
      reduceMotion: reduceMotion,
      parent: buildParent(ancestor),
    );
  }

  @override
  SpringDescription get spring =>
      reduceMotion ? MayhemSprings.snappy : MayhemSprings.standard;
}

class _FeedScene extends StatelessWidget {
  const _FeedScene({
    required this.item,
    required this.position,
    required this.total,
    required this.pageOffset,
  });

  final FeedFixtureItem item;
  final int position;
  final int total;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final backgroundLag = pageOffset * size.height * 0.11;
    final textLag = pageOffset * size.height * 0.045;
    final tilt = pageOffset * (math.pi / 90);

    return Semantics(
      container: true,
      label:
          '${item.kind.name}, $position of $total. ${item.statement}. ${item.detail}',
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: tilt,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(0, backgroundLag),
                child: _SceneMaterial(energy: item.energy),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MayhemColors.overlayScrim,
                      MayhemColors.canvasDeep,
                    ],
                    stops: [0, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Transform.translate(
                  offset: Offset(0, textLag),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MayhemSpacing.x5,
                      MayhemSpacing.x16,
                      MayhemSpacing.x5,
                      MayhemSpacing.x12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MayhemText(
                          item.eyebrow.toUpperCase(),
                          variant: MayhemTextVariant.labelMicro,
                          color: item.energy,
                        ),
                        const Spacer(),
                        MayhemText(
                          item.statement,
                          variant: MayhemTextVariant.displayMedium,
                          maxLines: 4,
                        ),
                        const SizedBox(height: MayhemSpacing.x4),
                        MayhemText(
                          item.detail,
                          variant: MayhemTextVariant.bodyLarge,
                          maxLines: 3,
                        ),
                        const SizedBox(height: MayhemSpacing.x10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneMaterial extends StatelessWidget {
  const _SceneMaterial({required this.energy});

  final Color energy;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SceneMaterialPainter(energy));
  }
}

class _SceneMaterialPainter extends CustomPainter {
  const _SceneMaterialPainter(this.energy);

  final Color energy;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = MayhemColors.canvasDeep,
    );
    final field = Paint()
      ..shader =
          RadialGradient(
            colors: [energy, MayhemColors.canvasDeep],
            stops: const [0, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.72, size.height * 0.28),
              radius: size.longestSide * 0.58,
            ),
          );
    canvas.drawRect(Offset.zero & size, field);

    final line = Paint()
      ..color = MayhemColors.lineStrong
      ..strokeWidth = 1;
    for (var index = 0; index < 5; index++) {
      final y = size.height * (0.14 + index * 0.11);
      canvas.drawLine(
        Offset(size.width * 0.16, y),
        Offset(size.width * 0.86, y - size.height * 0.08),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_SceneMaterialPainter oldDelegate) {
    return oldDelegate.energy != energy;
  }
}
