import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../theme/mayhem_theme.dart';

class BoundariesScreen extends StatefulWidget {
  const BoundariesScreen({super.key, required this.controller});

  final TodayController controller;

  @override
  State<BoundariesScreen> createState() => _BoundariesScreenState();
}

class _BoundariesScreenState extends State<BoundariesScreen> {
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            const Icon(
              Icons.shield_outlined,
              color: MayhemTheme.safety,
              size: 34,
            ),
            const SizedBox(height: 24),
            Text(
              'ТВОИ ГРАНИЦЫ ВАЖНЕЕ ЗАДАНИЯ',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 18),
            const _BoundaryLine(
              text:
                  'Это игровая практика, а не терапия или медицинская помощь.',
            ),
            const _BoundaryLine(
              text: 'Любой вызов можно отложить без штрафа и объяснений.',
            ),
            const _BoundaryLine(
              text: 'Не продолжай контакт, если другому человеку некомфортно.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Если тебе тяжело или небезопасно, остановись и обратись к подходящему специалисту или местной службе помощи.',
              style: TextStyle(color: MayhemTheme.muted, height: 1.45),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: saving ? null : _acknowledge,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('ПОНЯТНО, ПРОДОЛЖИТЬ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acknowledge() async {
    setState(() => saving = true);
    try {
      await widget.controller.acknowledgeBoundaries();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить выбор.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _BoundaryLine extends StatelessWidget {
  const _BoundaryLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 18, color: MayhemTheme.safety),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: MayhemTheme.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
