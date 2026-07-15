import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../theme/mayhem_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final TodayController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool deleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('НАСТРОЙКИ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionTitle('О ПРИЛОЖЕНИИ'),
          const SizedBox(height: 12),
          const Text(
            'MAYHEM — приватная игровая практика социальных действий. Это не терапия, не медицинский продукт и не замена профессиональной помощи.',
            style: TextStyle(color: MayhemTheme.ink, height: 1.5),
          ),
          const SizedBox(height: 14),
          const Text(
            'Любой вызов можно отложить без штрафа. Не продолжай контакт без взаимного комфорта. В кризисной или небезопасной ситуации используй подходящую профессиональную или экстренную помощь.',
            style: TextStyle(color: MayhemTheme.muted, height: 1.5),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(color: MayhemTheme.line),
          ),
          const _SectionTitle('ДАННЫЕ НА УСТРОЙСТВЕ'),
          const SizedBox(height: 12),
          const Text(
            'Сейчас прогресс хранится только локально: XP, история событий и приватные Reflection. Серверный аккаунт ещё не создаётся.',
            style: TextStyle(color: MayhemTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: deleting ? null : _confirmDelete,
            icon: deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: const Text('УДАЛИТЬ ЛОКАЛЬНЫЕ ДАННЫЕ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить прогресс?'),
        content: const Text(
          'Будут удалены XP, история квестов, события и Reflection на этом устройстве. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ОТМЕНА'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => deleting = true);
    try {
      await widget.controller.clearLocalData();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить локальные данные.')),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
    );
  }
}
