import 'challenge_models.dart';

abstract interface class ChallengeAttemptRepository {
  Future<ChallengeAttempt?> activeAttempt();

  Future<ChallengeAttempt?> findById(String attemptId);

  Future<ChallengeAttempt?> findByAssignment(String assignmentId);

  Future<void> save(ChallengeAttempt attempt);

  Future<List<ChallengeAttempt>> history({int limit = 100});
}
