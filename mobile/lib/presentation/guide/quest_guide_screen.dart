import 'package:flutter/material.dart';

import '../../domain/models/quest.dart';
import '../../domain/models/quest_guide.dart';
import '../theme/mayhem_theme.dart';

class QuestGuideScreen extends StatelessWidget {
  const QuestGuideScreen({super.key, required this.quest, required this.guide});

  final Quest quest;
  final QuestGuide guide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('РАЗБОР')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(quest.category.toUpperCase(), style: _eyebrowStyle),
          const SizedBox(height: 8),
          Text(quest.text, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 28),
          const Text('МАРШРУТ', style: _eyebrowStyle),
          const SizedBox(height: 12),
          ...guide.steps.indexed.map(
            (entry) => _GuideStep(index: entry.$1 + 1, text: entry.$2),
          ),
          const SizedBox(height: 24),
          const Text('РАБОЧИЕ ФРАЗЫ', style: _eyebrowStyle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: guide.phrases
                .map(
                  (phrase) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: MayhemTheme.raised,
                      border: Border.all(color: MayhemTheme.line),
                    ),
                    child: Text(
                      phrase,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 26),
          _GuideSection(title: 'ДРУГОЙ МАРШРУТ', text: guide.alternateRoute),
          _GuideSection(title: 'УСЛОЖНЕНИЕ', text: guide.advancedRoute),
          _GuideSection(
            title: 'ЧИСТЫЙ ВЫХОД',
            text: guide.exitScript,
            accent: true,
          ),
        ],
      ),
    );
  }
}

const _eyebrowStyle = TextStyle(
  color: MayhemTheme.muted,
  fontSize: 11,
  fontWeight: FontWeight.w900,
  letterSpacing: 1.1,
);

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            color: MayhemTheme.signal,
            child: Text(
              index.toString(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text,
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.text,
    this.accent = false,
  });

  final String title;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MayhemTheme.surface,
        border: Border(
          left: BorderSide(
            color: accent ? MayhemTheme.safety : MayhemTheme.line,
            width: accent ? 3 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _eyebrowStyle),
          const SizedBox(height: 7),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
