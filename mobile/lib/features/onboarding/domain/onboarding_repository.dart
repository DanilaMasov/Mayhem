import 'onboarding_models.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingProgress?> load();

  Future<void> save(OnboardingProgress progress);

  Future<void> clear();
}
