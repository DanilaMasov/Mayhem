class PrivateReflection {
  const PrivateReflection({
    required this.reflectionId,
    required this.attemptId,
    required this.createdAt,
    required this.updatedAt,
    this.fearBefore,
    this.feelAfter,
    this.wantRepeat,
    this.privateNote,
  });

  final String reflectionId;
  final String attemptId;
  final int? fearBefore;
  final int? feelAfter;
  final bool? wantRepeat;
  final String? privateNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  void validate() {
    if (reflectionId.trim().isEmpty || attemptId.trim().isEmpty) {
      throw const FormatException('Reflection identity is invalid');
    }
    for (final score in [fearBefore, feelAfter]) {
      if (score != null && (score < 1 || score > 10)) {
        throw const FormatException(
          'Reflection score must be between 1 and 10',
        );
      }
    }
    if ((privateNote?.length ?? 0) > 2000) {
      throw const FormatException('Private reflection note is too long');
    }
  }
}
