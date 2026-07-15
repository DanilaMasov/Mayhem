import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../../domain/models/quest.dart';
import '../../domain/models/quest_reflection.dart';
import '../../domain/services/game_engine.dart';
import '../theme/mayhem_theme.dart';

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({
    super.key,
    required this.controller,
    required this.quest,
  });

  final TodayController controller;
  final Quest quest;

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  final noteController = TextEditingController();
  double fearScore = 5;
  double feelAfterScore = 6;
  bool wantRepeat = true;
  bool saving = false;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REFLECTION'),
        actions: [
          TextButton(
            onPressed: saving ? null : () => _submit(skip: true),
            child: const Text('Пропустить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('КАК ПРОШЛО?', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            widget.quest.text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          _ScoreField(
            label: 'Напряжение до действия',
            value: fearScore,
            onChanged: (value) => setState(() => fearScore = value),
          ),
          const SizedBox(height: 14),
          _ScoreField(
            label: 'Состояние после',
            value: feelAfterScore,
            onChanged: (value) => setState(() => feelAfterScore = value),
          ),
          const SizedBox(height: 20),
          const Text(
            'ХОЧЕШЬ ПОВТОРИТЬ?',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Да')),
              ButtonSegment(value: false, label: Text('Нет')),
            ],
            selected: {wantRepeat},
            showSelectedIcon: false,
            onSelectionChanged: saving
                ? null
                : (selection) => setState(() => wantRepeat = selection.single),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: noteController,
            enabled: !saving,
            maxLength: 240,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Заметка для себя',
              hintText: 'Что сработало и что изменить в следующий раз',
              filled: true,
              fillColor: MayhemTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(2)),
                borderSide: BorderSide(color: MayhemTheme.line),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: saving ? null : () => _submit(skip: false),
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('СОХРАНИТЬ И ЗАКРЫТЬ'),
        ),
      ),
    );
  }

  Future<void> _submit({required bool skip}) async {
    setState(() => saving = true);
    try {
      await widget.controller.completeQuest(
        widget.quest,
        skipReflection: skip,
        reflection: skip
            ? null
            : ReflectionDraft(
                fearScore: fearScore.round(),
                feelAfterScore: feelAfterScore.round(),
                wantRepeat: wantRepeat,
                note: noteController.text,
              ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on GameRuleException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Не удалось сохранить reflection. Попробуй ещё раз.');
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

class _ScoreField extends StatelessWidget {
  const _ScoreField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: MayhemTheme.surface,
        border: Border.all(color: MayhemTheme.line),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                value.round().toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
