import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../../domain/models/npc_dialog.dart';
import '../../domain/models/quest.dart';
import '../../domain/services/game_engine.dart';
import '../theme/mayhem_theme.dart';

class RehearsalScreen extends StatefulWidget {
  const RehearsalScreen({
    super.key,
    required this.controller,
    required this.quest,
    required this.dialog,
  });

  final TodayController controller;
  final Quest quest;
  final NpcDialog dialog;

  @override
  State<RehearsalScreen> createState() => _RehearsalScreenState();
}

class _RehearsalScreenState extends State<RehearsalScreen> {
  late String nodeId = widget.dialog.startNodeId;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.dialog.node(nodeId);
    return Scaffold(
      appBar: AppBar(title: const Text('РЕПЕТИЦИЯ')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.quest.category.toUpperCase(), style: _eyebrowStyle),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: node.speaker == DialogSpeaker.coach
                            ? const Color(0xFF151305)
                            : MayhemTheme.surface,
                        border: Border.all(
                          color: node.speaker == DialogSpeaker.coach
                              ? MayhemTheme.safety
                              : MayhemTheme.line,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.speaker == DialogSpeaker.coach
                                ? 'COACH'
                                : 'СОБЕСЕДНИК',
                            style: _eyebrowStyle,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            node.text,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!node.success)
                      ...node.options.map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => setState(
                                    () => nodeId = option.nextNodeId,
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                option.label,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (node.success)
                FilledButton.icon(
                  onPressed: saving ? null : _complete,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('ЗАВЕРШИТЬ РЕПЕТИЦИЮ'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _complete() async {
    setState(() => saving = true);
    try {
      await widget.controller.completeTraining(widget.quest);
      if (mounted) Navigator.of(context).pop(true);
    } on GameRuleException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Не удалось сохранить репетицию.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

const _eyebrowStyle = TextStyle(
  color: MayhemTheme.muted,
  fontSize: 11,
  fontWeight: FontWeight.w900,
  letterSpacing: 1.1,
);
