import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/content/data/bundled_vnext_content_adapter.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';
import 'package:mayhem_mobile/data/catalog/bundled_quest_catalog.dart';
import 'package:mayhem_mobile/features/feed/domain/local_feed_batch_policy.dart';

void main() {
  test(
    'local batch satisfies launch ordering and diversity constraints',
    () async {
      final content = await _content();
      var id = 0;
      final generated = const LocalFeedBatchPolicy().generate(
        revisions: content.revisions,
        completedContentIds: const {},
        localUserId: 'local-user',
        nowUtc: DateTime.utc(2026, 7, 13, 12),
        idGenerator: () => 'id-${id++}',
      );

      expect(generated.assignments, hasLength(20));
      expect(generated.assignments.first.position, 0);
      expect(
        generated.assignments.first.boundedMetadata['contentType'],
        ContentItemType.challenge.name,
      );
      expect(
        generated.assignments.map((item) => item.contentId).toSet(),
        hasLength(20),
      );
      for (var index = 2; index < generated.assignments.length; index++) {
        final current =
            generated.assignments[index].boundedMetadata['contentType'];
        expect(
          current ==
                  generated
                      .assignments[index - 1]
                      .boundedMetadata['contentType'] &&
              current ==
                  generated
                      .assignments[index - 2]
                      .boundedMetadata['contentType'],
          isFalse,
        );
      }
      expect(
        generated.assignments
            .take(5)
            .where(
              (item) => (item.boundedMetadata['intensity'] as int? ?? 0) >= 4,
            ),
        hasLength(lessThanOrEqualTo(2)),
      );
      expect(
        generated.assignments
            .take(6)
            .any(
              (item) => item.boundedMetadata['lowPressureAvailable'] == true,
            ),
        isTrue,
      );
    },
  );

  test(
    'local batch fails honestly instead of repeating completed content',
    () async {
      final content = await _content();
      final completedChallenge = content.revisions.firstWhere(
        (item) => item.type == ContentItemType.challenge,
      );

      expect(
        () => const LocalFeedBatchPolicy().generate(
          revisions: content.revisions,
          completedContentIds: {completedChallenge.contentId},
          localUserId: 'local-user',
          nowUtc: DateTime.utc(2026, 7, 13, 12),
          idGenerator: () => 'id',
        ),
        throwsA(
          isA<FeedBatchGenerationException>().having(
            (error) => error.code,
            'code',
            'insufficient_challenge_content',
          ),
        ),
      );
    },
  );
}

Future<BundledVNextContent> _content() async {
  final source = await File('assets/content/quest_catalog.json').readAsString();
  final legacy = BundledQuestCatalog.fromJson(
    jsonDecode(source) as Map<String, dynamic>,
  );
  return const BundledVNextContentAdapter().adapt(
    legacy,
    publishedAt: DateTime.utc(2026, 7, 13),
  );
}
