class RemoteAuthSession {
  RemoteAuthSession({
    required this.remoteUserId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.isAnonymous,
  }) {
    if (remoteUserId.trim().isEmpty ||
        accessToken.trim().isEmpty ||
        refreshToken.trim().isEmpty ||
        !expiresAt.isUtc) {
      throw const FormatException('Remote auth session is invalid');
    }
  }

  final String remoteUserId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final bool isAnonymous;

  bool isUsableAt(DateTime now, {Duration skew = const Duration(minutes: 1)}) =>
      expiresAt.isAfter(now.toUtc().add(skew));

  @override
  String toString() =>
      'RemoteAuthSession(remoteUserId: $remoteUserId, '
      'accessToken: <redacted>, refreshToken: <redacted>, '
      'expiresAt: ${expiresAt.toIso8601String()}, isAnonymous: $isAnonymous)';
}
