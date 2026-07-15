import '../../../core/crypto/sha256.dart';

abstract final class RemoteContentChecksum {
  static String compute(Map<String, dynamic> json) => Sha256.hexOfString(
    canonicalJson({
      'contentId': json['contentId'],
      'revision': json['revision'],
      'locale': json['locale'],
      'type': json['type'],
      'payload': json['payload'],
      'safety': json['safety'],
      'media': json['media'],
    }),
  );
}
