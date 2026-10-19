import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/gherkin/scenario_metadata.dart';
import '../../../integration_test/models/test_tags.dart';

void main() {
  final today = DateTime(2026, 10, 19);

  ScenarioMetadata parse(List<String> tags) =>
      ScenarioMetadata.parse(tags, today: today);

  Matcher throwsProblems(List<String> problems) => throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(problems.map(contains).toList()),
        ),
      );

  group('ScenarioMetadata.parse', () {
    test('reads every kind of tag of a complete scenario', () {
      final metadata = parse([
        'NR-COMPOSER-001',
        'P1',
        'web',
        'android',
        'smoke',
        'src:issue-4488',
        'src:pr-4539',
        'verified:2026-10-16',
      ]);

      expect(metadata.id, 'NR-COMPOSER-001');
      expect(metadata.priority, 'P1');
      expect(metadata.platforms, [TestTags.web, TestTags.android]);
      expect(metadata.groups, ['smoke']);
      expect(metadata.sources, ['issue-4488', 'pr-4539']);
      expect(metadata.verifiedOn, DateTime.utc(2026, 10, 16));
    });

    test('accepts tags written with the leading @', () {
      final metadata = parse(['@NR-SEARCH-012', '@P3', '@ios']);

      expect(metadata.id, 'NR-SEARCH-012');
      expect(metadata.priority, 'P3');
      expect(metadata.platforms, [TestTags.ios]);
    });

    test('leaves optional metadata empty when absent', () {
      final metadata = parse(['NR-COMPOSER-001', 'P2', 'web']);

      expect(metadata.groups, isEmpty);
      expect(metadata.sources, isEmpty);
      expect(metadata.verifiedOn, isNull);
    });

    test('accepts a verification dated today', () {
      final metadata = parse(['NR-COMPOSER-001', 'P2', 'web', 'verified:2026-10-19']);

      expect(metadata.verifiedOn, DateTime.utc(2026, 10, 19));
    });

    test('reports every missing required tag at once', () {
      expect(
        () => parse(['smoke']),
        throwsProblems([
          'missing id @NR-<AREA>-<NNN>',
          'missing priority @P1, @P2 or @P3',
          'missing platform @android, @ios or @web',
        ]),
      );
    });

    test('rejects more than one id or priority', () {
      expect(
        () => parse(['NR-COMPOSER-001', 'NR-COMPOSER-002', 'P1', 'P2', 'web']),
        throwsProblems([
          'more than one id @NR-<AREA>-<NNN>: NR-COMPOSER-001, NR-COMPOSER-002',
          'more than one priority @P1, @P2 or @P3: P1, P2',
        ]),
      );
    });

    for (final tag in [
      'nr-composer-001',
      'NR-COMPOSER-1',
      'NR--001',
      'P4',
      'linux',
      'slow',
      'src:pr-0',
      'src:commit-abc123',
      'src:pr-4539x',
      'verifiedAt:2026-10-16',
    ]) {
      test('rejects the unknown tag $tag', () {
        expect(
          () => parse(['NR-COMPOSER-001', 'P2', 'web', tag]),
          throwsProblems(['unknown tag @$tag']),
        );
      });
    }

    for (final tag in [
      'verified:2026-02-30',
      'verified:2026-13-01',
      'verified:2026-1-5',
      'verified:yesterday',
    ]) {
      test('rejects the malformed date $tag', () {
        expect(
          () => parse(['NR-COMPOSER-001', 'P2', 'web', tag]),
          throwsProblems(['@$tag is not a valid YYYY-MM-DD date']),
        );
      });
    }

    test('rejects a verification dated after today', () {
      expect(
        () => parse(['NR-COMPOSER-001', 'P2', 'web', 'verified:2026-10-20']),
        throwsProblems(['@verified:2026-10-20 is in the future']),
      );
    });

    test('rejects more than one verification date', () {
      expect(
        () => parse([
          'NR-COMPOSER-001',
          'P2',
          'web',
          'verified:2026-10-01',
          'verified:2026-10-02',
        ]),
        throwsProblems(['more than one @verified date']),
      );
    });
  });

  group('ScenarioMetadata.selectableTags', () {
    test('keeps selection tags and drops key:value metadata', () {
      final metadata = parse([
        'NR-COMPOSER-001',
        'P1',
        'web',
        'ios',
        'smoke',
        'src:pr-4539',
        'verified:2026-10-16',
      ]);

      expect(
        metadata.selectableTags,
        ['gherkin', 'NR-COMPOSER-001', 'P1', 'web', 'ios', 'smoke'],
      );
    });

    test('are all valid test_api tag names', () {
      final metadata = parse([
        'NR-COMPOSER-001',
        'P1',
        'web',
        'smoke',
        'src:pr-4539',
        'verified:2026-10-16',
      ]);
      final testApiTagName = RegExp(r'^[a-zA-Z_-][a-zA-Z0-9_-]*$');

      expect(metadata.selectableTags, everyElement(matches(testApiTagName)));
    });
  });
}
