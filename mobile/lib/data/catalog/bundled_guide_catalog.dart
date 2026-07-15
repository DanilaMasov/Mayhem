import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/quest_guide.dart';

class BundledGuideCatalog {
  const BundledGuideCatalog._();

  static Future<GuideCatalog> load(
    AssetBundle bundle, {
    String assetPath = 'assets/content/guide_catalog.json',
  }) async {
    final raw = await bundle.loadString(assetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Guide catalog root must be an object');
    }
    return fromJson(json);
  }

  static GuideCatalog fromJson(Map<String, dynamic> json) {
    final records = json['guides'];
    if (records is! List<dynamic>) {
      throw const FormatException('Guide catalog records must be an array');
    }
    return GuideCatalog(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      guides: records
          .map((item) => QuestGuide.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
