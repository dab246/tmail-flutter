import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

final _invalidEntries = <String, (Map<String, Object?>, String)>{
  'it has no reason': ({'maxLostLinks': 1}, 'eml_7: every policy needs a "reason"'),
  'a key is misspelled': ({'reason': 'r', 'maxLostLink': 1}, 'eml_7: unknown key "maxLostLink"'),
  'an override key is misspelled': (
    {'reason': 'r', 'pipelines': {'print': {'maxLostImage': 1}}},
    'eml_7.pipelines.print: unknown key "maxLostImage"',
  ),
};

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('policy_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  File policies(Object json) => File('${temp.path}/policies.json')..writeAsStringSync(jsonEncode(json));

  group('PolicyBook', () {
    test('SHOULD be strict for every fixture WHEN the file does not exist', () {
      final book = PolicyBook.load(File('${temp.path}/missing.json'));

      final policy = book.forFixture('eml_1');
      expect(policy.maxMissingTextTokens, 0);
      expect(policy.maxLostLinks, 0);
      expect(policy.maxLostImages, 0);
      expect(policy.allowHorizontalOverflow, isEmpty);
      expect(policy.skipPixel, isNull);
    });

    test('SHOULD apply a fixture policy and merge a pipeline override over it', () {
      final book = PolicyBook.load(policies({
        'eml_7': {
          'reason': 'newsletter',
          'allowHorizontalOverflow': ['web'],
          'maxLostLinks': 1,
          'pipelines': {
            'print': {'maxLostImages': 2},
          },
        },
      }));

      final general = book.forFixture('eml_7', pipeline: 'preview-web');
      final print = book.forFixture('eml_7', pipeline: 'print');

      expect(general.allowHorizontalOverflow, {'web'});
      expect(general.maxLostImages, 0);
      expect(print.maxLostImages, 2);
      expect(print.maxLostLinks, 1);
      expect(print.allowHorizontalOverflow, {'web'});
      expect(book.forFixture('eml_1').maxLostLinks, 0);
    });

    for (final MapEntry(key: problem, value: (entry, message)) in _invalidEntries.entries) {
      test('SHOULD reject an entry WHEN $problem', () {
        expect(
          () => PolicyBook.load(policies({'eml_7': entry})),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(message))),
        );
      });
    }

    test('SHOULD list the pipelines its overrides name', () {
      final book = PolicyBook.load(policies({
        'eml_7': {'reason': 'r', 'pipelines': {'print': {}, 'preview-web': {}}},
        'eml_8': {'reason': 'r'},
      }));

      expect(book.pipelineNames, {'print', 'preview-web'});
    });

    test('SHOULD serialize the policy for the pixel runner', () {
      const policy = FixturePolicy(allowHorizontalOverflow: {'web', 'native-ios'}, skipPixel: 'flaky');

      expect(policy.toJson(), {
        'maxMissingTextTokens': 0,
        'maxLostLinks': 0,
        'maxLostImages': 0,
        'allowHorizontalOverflow': ['native-ios', 'web'],
        'skipPixel': 'flaky',
      });
    });
  });
}
