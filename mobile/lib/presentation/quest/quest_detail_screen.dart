import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../../domain/models/quest.dart';
import '../../domain/services/game_engine.dart';
import '../guide/quest_guide_screen.dart';
import '../reflection/reflection_screen.dart';
import '../rehearsal/rehearsal_screen.dart';
import '../theme/mayhem_theme.dart';

class QuestDetailScreen extends StatefulWidget {
  const QuestDetailScreen({
    super.key,
    required this.controller,
    required this.quest,
    this.showModifier = true,
  });

  final TodayController controller;
  final Quest quest;
  final bool showModifier;

  @override
  State<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends State<QuestDetailScreen> {
  bool alternateRoute = false;
  bool rollingModifier = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final active =
            widget.controller.state.activeQuest?.questId == widget.quest.id;
        final trained = widget.controller.isTrained(widget.quest.id);
        final modifier = widget.controller.modifierFor(widget.quest);
        final allowance = widget.controller.modifierAllowance;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.quest.isBoss
                  ? 'DAILY DROP'
                  : 'RUN // L${widget.quest.level}',
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: widget.quest.isBoss
                      ? const Color(0xFF151305)
                      : MayhemTheme.surface,
                  border: Border.all(
                    color: widget.quest.isBoss
                        ? MayhemTheme.safety
                        : MayhemTheme.line,
                    width: widget.quest.isBoss ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.quest.category.toUpperCase(),
                          style: const TextStyle(
                            color: MayhemTheme.muted,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          widget.quest.statType.label.toUpperCase(),
                          style: const TextStyle(
                            color: MayhemTheme.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.quest.text,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: MayhemTheme.signal,
                          size: 18,
                        ),
                        Text(' ${widget.quest.energyCost}% энергии'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _openGuide,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('ОТКРЫТЬ РАЗБОР'),
              ),
              if (widget.controller.hasDialog(widget.quest.id)) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: active || trained ? null : _openRehearsal,
                  icon: Icon(trained ? Icons.check : Icons.forum_outlined),
                  label: Text(
                    trained ? 'РЕПЕТИЦИЯ ГОТОВА' : 'НАЧАТЬ РЕПЕТИЦИЮ',
                  ),
                ),
              ],
              if (widget.showModifier && !widget.quest.isShadow) ...[
                const SizedBox(height: 18),
                const Text(
                  'МОДИФИКАТОР',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                ),
                const SizedBox(height: 8),
                if (modifier != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MayhemTheme.raised,
                      border: Border.all(color: MayhemTheme.signal),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.casino_outlined,
                          color: MayhemTheme.signal,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                modifier.title.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                modifier.text,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (modifier != null) const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      active ||
                          rollingModifier ||
                          modifier != null ||
                          !allowance.canRoll
                      ? null
                      : _rollModifier,
                  icon: rollingModifier
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.casino_outlined),
                  label: Text(
                    active
                        ? 'МОДИФИКАТОР ЗАФИКСИРОВАН'
                        : modifier != null
                        ? 'БРОСОК ИСПОЛЬЗОВАН'
                        : allowance.canRoll
                        ? 'БРОСИТЬ КУБИК · ${allowance.remaining}/1'
                        : 'ЛИМИТ НА СЕГОДНЯ',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Основной')),
                  ButtonSegment(value: true, label: Text('Другой маршрут')),
                ],
                selected: {alternateRoute},
                showSelectedIcon: false,
                onSelectionChanged: active
                    ? null
                    : (selection) =>
                          setState(() => alternateRoute = selection.single),
              ),
              const SizedBox(height: 12),
              Text(
                alternateRoute
                    ? widget.quest.alternateRoute
                    : widget.quest.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const Text(
                'УСЛОЖНЕНИЕ',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Text(
                widget.quest.advancedRoute,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: active
                ? Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _openReflection,
                          icon: const Icon(Icons.check),
                          label: const Text('ЗАКРЫТЬ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _runAction(
                            () => widget.controller.deferQuest(widget.quest),
                            closeAfter: true,
                          ),
                          child: const Text('СОЙТИ'),
                        ),
                      ),
                    ],
                  )
                : FilledButton.icon(
                    onPressed: () => _runAction(
                      () => widget.controller.startQuest(
                        widget.quest,
                        variant: alternateRoute ? 'low_pressure' : 'normal',
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ПРИНЯТЬ ВЫЗОВ'),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    bool closeAfter = false,
  }) async {
    try {
      await action();
      if (closeAfter && mounted) Navigator.of(context).pop();
    } on GameRuleException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить действие. Попробуй ещё раз.'),
        ),
      );
    }
  }

  Future<void> _openReflection() async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReflectionScreen(
          controller: widget.controller,
          quest: widget.quest,
        ),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _openGuide() async {
    try {
      await widget.controller.openGuide(widget.quest);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => QuestGuideScreen(
            quest: widget.quest,
            guide: widget.controller.guideFor(widget.quest.id),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть разбор.')),
      );
    }
  }

  Future<void> _openRehearsal() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RehearsalScreen(
          controller: widget.controller,
          quest: widget.quest,
          dialog: widget.controller.dialogFor(widget.quest.id),
        ),
      ),
    );
  }

  Future<void> _rollModifier() async {
    setState(() => rollingModifier = true);
    try {
      await _runAction(() => widget.controller.rollModifier(widget.quest));
    } finally {
      if (mounted) setState(() => rollingModifier = false);
    }
  }
}
