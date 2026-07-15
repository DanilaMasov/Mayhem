import 'dart:convert';

import '../../../core/metadata/local_metadata_repository.dart';
import '../domain/onboarding_models.dart';
import '../domain/onboarding_repository.dart';

class LocalOnboardingRepository implements OnboardingRepository {
  const LocalOnboardingRepository(this.metadata);

  static const metadataKey = 'onboarding_vnext_v1';

  final LocalMetadataRepository metadata;

  @override
  Future<OnboardingProgress?> load() async {
    final source = await metadata.read(metadataKey);
    if (source == null) return null;
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stored onboarding state is invalid');
    }
    return OnboardingProgress.fromJson(decoded);
  }

  @override
  Future<void> save(OnboardingProgress progress) =>
      metadata.write(metadataKey, jsonEncode(progress.toJson()));

  @override
  Future<void> clear() => metadata.delete(metadataKey);
}
