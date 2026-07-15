import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/npc_dialog.dart';

class BundledDialogCatalog {
  const BundledDialogCatalog._();

  static Future<DialogCatalog> load(
    AssetBundle bundle, {
    String assetPath = 'assets/content/dialog_catalog.json',
  }) async {
    final raw = await bundle.loadString(assetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Dialog catalog root must be an object');
    }
    return fromJson(json);
  }

  static DialogCatalog fromJson(Map<String, dynamic> json) {
    final records = json['dialogs'];
    if (records is! List<dynamic>) {
      throw const FormatException('Dialog catalog records must be an array');
    }
    return DialogCatalog(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      dialogs: records
          .map((item) => NpcDialog.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
