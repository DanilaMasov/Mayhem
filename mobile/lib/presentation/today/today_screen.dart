import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/quest.dart';
import '../quest/quest_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../theme/mayhem_theme.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.controller});

  final TodayController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.error.isNotEmpty) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(controller.error, textAlign: TextAlign.center),
              ),
            ),
          );
        }
        final state = controller.state;
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _BrandBar(
                    onProfile: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileScreen(controller: controller),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EnergyBand(energy: state.energy, xp: state.totalXp),
                  const SizedBox(height: 28),
                  Text(
                    'DAILY DROP // ${state.daily.bossDate}',
                    style: const TextStyle(
                      color: MayhemTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ВЫЗОВ ДНЯ',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 14),
                  _QuestTile(
                    quest: controller.bossQuest,
                    primary: true,
                    completed: _isCompleted(
                      state.completedByDate,
                      controller.bossQuest,
                      state.daily,
                    ),
                    onTap: () => _openQuest(context, controller.bossQuest),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(thickness: 3, color: MayhemTheme.ink),
                  ),
                  const _SectionHeading(
                    title: 'BACKUP RUNS',
                    trailing: 'ЕЩЁ 2',
                  ),
                  const SizedBox(height: 10),
                  ...controller.localQuests.map(
                    (quest) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _QuestTile(
                        quest: quest,
                        completed: _isCompleted(
                          state.completedByDate,
                          quest,
                          state.daily,
                        ),
                        onTap: () => _openQuest(context, quest),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isCompleted(
    Map<String, List<String>> completed,
    Quest quest,
    DailySelection daily,
  ) {
    final key = quest.isBoss ? daily.bossDate : daily.localDate;
    return completed[key]?.contains(quest.id) == true;
  }

  void _openQuest(BuildContext context, Quest quest) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestDetailScreen(controller: controller, quest: quest),
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  const _BrandBar({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          color: MayhemTheme.signal,
          alignment: Alignment.center,
          child: const Text(
            'M',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAYHEM',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                'SOCIAL CHALLENGE',
                style: TextStyle(
                  color: MayhemTheme.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onProfile,
          tooltip: 'Профиль',
          icon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }
}

class _EnergyBand extends StatelessWidget {
  const _EnergyBand({required this.energy, required this.xp});

  final int energy;
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: MayhemTheme.surface,
        border: Border.fromBorderSide(BorderSide(color: MayhemTheme.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: MayhemTheme.signal),
          const SizedBox(width: 8),
          Text(
            '$energy%',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: LinearProgressIndicator(
              value: energy / 100,
              minHeight: 4,
              color: MayhemTheme.signal,
              backgroundColor: MayhemTheme.line,
            ),
          ),
          const SizedBox(width: 14),
          Text('$xp XP', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        Text(
          trailing,
          style: const TextStyle(color: MayhemTheme.muted, fontSize: 10),
        ),
      ],
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.quest,
    required this.onTap,
    required this.completed,
    this.primary = false,
  });

  final Quest quest;
  final VoidCallback onTap;
  final bool completed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = primary ? MayhemTheme.safety : MayhemTheme.signal;
    return Material(
      color: primary ? const Color(0xFF151305) : MayhemTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        side: BorderSide(color: accent, width: primary ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                color: accent.withValues(alpha: 0.12),
                child: Icon(
                  primary ? Icons.public : Icons.chat_bubble_outline,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            primary
                                ? 'ГЛАВНЫЙ ВЫЗОВ'
                                : 'RUN // L${quest.level}',
                            style: const TextStyle(
                              color: MayhemTheme.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          quest.isShadow
                              ? '+${quest.rewardEnergy}%'
                              : '−${quest.energyCost}%',
                          style: const TextStyle(
                            color: MayhemTheme.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      quest.text,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      completed ? 'ЗАКРЫТО' : quest.statType.label,
                      style: TextStyle(
                        color: completed
                            ? MayhemTheme.safety
                            : MayhemTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
