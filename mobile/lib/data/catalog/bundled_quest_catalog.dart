import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/quest.dart';
import '../../domain/models/quest_catalog.dart';

class BundledQuestCatalog {
  const BundledQuestCatalog._();

  static Future<QuestCatalog> load(
    AssetBundle bundle, {
    String assetPath = 'assets/content/quest_catalog.json',
  }) async {
    final raw = await bundle.loadString(assetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Quest catalog root must be an object');
    }
    return fromJson(json);
  }

  static QuestCatalog fromJson(Map<String, dynamic> json) {
    final catalog = QuestCatalog(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      quests: _parseList(json['quests']),
      bosses: _parseList(json['bosses']),
    );
    catalog.validateBundledContract();
    return catalog;
  }

  static List<Quest> _parseList(Object? value) {
    if (value is! List<dynamic>) {
      throw const FormatException('Catalog pool must be an array');
    }
    return value
        .map((item) => Quest.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
