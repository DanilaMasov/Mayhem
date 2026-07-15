import 'dart:convert';

import '../../../core/metadata/local_metadata_repository.dart';
import '../domain/user_preferences.dart';

class LocalUserPreferencesRepository {
  const LocalUserPreferencesRepository(this.metadata);

  static const metadataKey = 'user_preferences_v1';

  final LocalMetadataRepository metadata;

  Future<UserPreferences> load() async {
    final source = await metadata.read(metadataKey);
    if (source == null) return const UserPreferences();
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stored user preferences are invalid');
    }
    return UserPreferences.fromJson(decoded);
  }

  Future<void> save(UserPreferences preferences) =>
      metadata.write(metadataKey, jsonEncode(preferences.toJson()));
}
