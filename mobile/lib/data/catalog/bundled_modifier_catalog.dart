import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/quest_modifier.dart';

class BundledModifierCatalog {
  const BundledModifierCatalog._();

  static Future<ModifierCatalog> load(
    AssetBundle bundle, {
    String assetPath = 'assets/content/modifier_catalog.json',
  }) async {
    final raw = await bundle.loadString(assetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Modifier catalog root must be an object');
    }
    return fromJson(json);
  }

  static ModifierCatalog fromJson(Map<String, dynamic> json) {
    final records = json['modifiers'];
    if (records is! List<dynamic>) {
      throw const FormatException('Modifier catalog records must be an array');
    }
    final catalog = ModifierCatalog(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      modifiers: records
          .map((item) => QuestModifier.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
    catalog.validateBundledContract();
    return catalog;
  }
}
