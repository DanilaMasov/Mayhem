import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../../domain/models/quest.dart';
import '../theme/mayhem_theme.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});

  final TodayController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final history = <({String date, Quest quest})>[];
    for (final entry in state.completedByDate.entries) {
      for (final questId in entry.value) {
        try {
          history.add((date: entry.key, quest: controller.questById(questId)));
        } on StateError {
          continue;
        }
      }
    }
    history.sort((left, right) => right.date.compareTo(left.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ПРОФИЛЬ'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '${state.totalXp} XP',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Выполнено офлайн-вызовов: ${state.completedCount}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 26),
          const Text(
            'ХАРАКТЕРИСТИКИ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
          const SizedBox(height: 12),
          for (final type in StatType.values)
            _StatRow(label: type.label, value: state.xp[type] ?? 0),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(color: MayhemTheme.line),
          ),
          const Text(
            'ИСТОРИЯ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Text(
              'Завершённые вызовы появятся здесь.',
              style: TextStyle(color: MayhemTheme.muted),
            )
          else
            for (final item in history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.quest.text),
                subtitle: Text('${item.date} · ${item.quest.statType.label}'),
                trailing: const Icon(Icons.check, color: MayhemTheme.safety),
              ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (value % 250) / 250,
              minHeight: 5,
              color: MayhemTheme.signal,
              backgroundColor: MayhemTheme.line,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text('$value XP', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
