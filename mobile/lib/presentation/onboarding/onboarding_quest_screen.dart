import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../quest/quest_detail_screen.dart';
import '../theme/mayhem_theme.dart';

class OnboardingQuestScreen extends StatelessWidget {
  const OnboardingQuestScreen({super.key, required this.controller});

  final TodayController controller;

  @override
  Widget build(BuildContext context) {
    final quest = controller.onboardingQuest;
    final step = controller.state.completedCount + 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MAYHEM',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                'ПЕРВЫЕ ШАГИ // $step ИЗ 3',
                style: const TextStyle(
                  color: MayhemTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ЗАДАНИЕ $step',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              Text(
                quest.text,
                style: const TextStyle(
                  color: MayhemTheme.ink,
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.bolt, size: 18, color: MayhemTheme.signal),
                  const SizedBox(width: 6),
                  Text('${quest.energyCost}% энергии'),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => QuestDetailScreen(
                      controller: controller,
                      quest: quest,
                      showModifier: false,
                    ),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('ОТКРЫТЬ ВЫЗОВ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
