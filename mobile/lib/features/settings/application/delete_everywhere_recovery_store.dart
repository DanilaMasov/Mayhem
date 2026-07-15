import 'dart:convert';

import '../../../infrastructure/security/flutter_secure_session_store.dart';

enum DataDeletionStage {
  serverDeletion,
  cloudConfirmed,
  secureSessionCleared,
  localDataCleared,
}

class DataDeletionRecoveryMarker {
  const DataDeletionRecoveryMarker({
    required this.receiptId,
    required this.remoteUserId,
    required this.deletedAt,
    required this.stage,
  });

  final String receiptId;
  final String remoteUserId;
  final DateTime deletedAt;
  final DataDeletionStage stage;

  DataDeletionRecoveryMarker copyWith({required DataDeletionStage stage}) =>
      DataDeletionRecoveryMarker(
        receiptId: receiptId,
        remoteUserId: remoteUserId,
        deletedAt: deletedAt,
        stage: stage,
      );
}

abstract interface class DeleteEverywhereRecoveryStore {
  Future<DataDeletionRecoveryMarker?> read();

  Future<void> write(DataDeletionRecoveryMarker marker);

  Future<void> clear();
}

class SecureDeleteEverywhereRecoveryStore
    implements DeleteEverywhereRecoveryStore {
  SecureDeleteEverywhereRecoveryStore({
    required this.storage,
    required String environment,
  }) : _key = _recoveryKey(environment);

  static const _schemaVersion = 1;
  static const _maximumPayloadLength = 4096;
  static final RegExp _validEnvironment = RegExp(
    r'^[a-z0-9][a-z0-9._-]{0,63}$',
  );

  final SecureKeyValueStore storage;
  final String _key;

  @override
  Future<DataDeletionRecoveryMarker?> read() async {
    final payload = await storage.read(key: _key);
    if (payload == null) return null;
    try {
      return _decode(payload);
    } on FormatException {
      await storage.delete(key: _key);
      rethrow;
    }
  }

  @override
  Future<void> write(DataDeletionRecoveryMarker marker) {
    final payload = jsonEncode({
      'version': _schemaVersion,
      'receiptId': marker.receiptId,
      'remoteUserId': marker.remoteUserId,
      'deletedAt': marker.deletedAt.toUtc().toIso8601String(),
      'stage': marker.stage.name,
    });
    if (payload.length > _maximumPayloadLength) {
      throw const FormatException('Deletion recovery marker is too large');
    }
    return storage.write(key: _key, value: payload);
  }

  @override
  Future<void> clear() => storage.delete(key: _key);

  DataDeletionRecoveryMarker _decode(String payload) {
    if (payload.length > _maximumPayloadLength) {
      throw const FormatException('Deletion recovery marker is too large');
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != _schemaVersion ||
        decoded['receiptId'] is! String ||
        decoded['remoteUserId'] is! String ||
        decoded['deletedAt'] is! String ||
        decoded['stage'] is! String) {
      throw const FormatException('Deletion recovery marker is invalid');
    }
    final stage = DataDeletionStage.values
        .where((value) => value.name == decoded['stage'])
        .firstOrNull;
    if (stage != DataDeletionStage.cloudConfirmed &&
        stage != DataDeletionStage.secureSessionCleared) {
      throw const FormatException('Deletion recovery stage is invalid');
    }
    return DataDeletionRecoveryMarker(
      receiptId: decoded['receiptId'] as String,
      remoteUserId: decoded['remoteUserId'] as String,
      deletedAt: DateTime.parse(decoded['deletedAt'] as String).toUtc(),
      stage: stage!,
    );
  }

  static String _recoveryKey(String environment) {
    final normalized = environment.trim().toLowerCase();
    if (!_validEnvironment.hasMatch(normalized)) {
      throw const FormatException('Secure storage environment is invalid');
    }
    return 'mayhem.$normalized.delete_everywhere_recovery.v1';
  }
}
