import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../data/local_user_preferences_repository.dart';
import '../domain/user_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this.repository);

  final LocalUserPreferencesRepository repository;

  UserPreferences _preferences = const UserPreferences();
  bool _loading = true;

  UserPreferences get preferences => _preferences;
  bool get loading => _loading;

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();
    try {
      _preferences = await repository.load();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load preferences; using safe defaults',
        name: 'mayhem.settings',
        error: error,
        stackTrace: stackTrace,
      );
      _preferences = const UserPreferences();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> update(UserPreferences next) async {
    await repository.save(next);
    _preferences = next;
    developer.log('Local preferences updated', name: 'mayhem.settings');
    notifyListeners();
  }
}
