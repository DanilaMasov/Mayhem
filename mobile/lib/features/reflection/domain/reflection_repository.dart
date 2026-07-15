import 'private_reflection.dart';

abstract interface class ReflectionRepository {
  Future<PrivateReflection?> findForAttempt(String attemptId);

  Future<void> saveReflection(PrivateReflection reflection);

  Future<void> deleteForAttempt(String attemptId);
}
