import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

import '../support/temp_corpus.dart';

typedef _CorpusSpec = ({Map<String, String> files, Map<String, Object?> manifest, String message});

const _html = {'format': 'html'};

final _inconsistentCorpora = <String, _CorpusSpec>{
  'a file is missing from the manifest': (
    files: {'eml_1.html.gz': 'a', 'eml_2.html.gz': 'b'},
    manifest: {'eml_1': _html},
    message: 'eml_2 is on disk',
  ),
  'the manifest lists a fixture with no file': (
    files: {'eml_1.html.gz': 'a'},
    manifest: {'eml_1': _html, 'eml_9': _html},
    message: 'eml_9 is in manifest.json',
  ),
  'a gzipped file has an unknown suffix': (
    files: {'eml_1.html.gz': 'a', 'eml_2.htm.gz': 'b'},
    manifest: {'eml_1': _html},
    message: 'eml_2.htm.gz is gzipped but not',
  ),
  'the declared format does not match the file extension': (
    files: {'eml_1.txt.gz': 'a'},
    manifest: {'eml_1': _html},
    message: 'declared html',
  ),
};

void _expectInconsistent(Directory temp, _CorpusSpec corpus) {
  final dir = writeCorpus(temp, files: corpus.files, manifestFixtures: corpus.manifest);

  expect(
    () => FixtureCorpus.load(dir),
    throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(corpus.message))),
  );
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('corpus_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  group('FixtureCorpus.load', () {
    test('SHOULD load fixtures in natural order with their format, tags and content', () {
      final dir = writeCorpus(temp, files: {
        'eml_10.html.gz': '<p>ten</p>',
        'eml_2.html.gz': '<p>two</p>',
        'eml_3.txt.gz': 'three',
      }, manifestFixtures: {
        'eml_10': {'format': 'html', 'tags': ['quotes']},
        'eml_2': {'format': 'html'},
        'eml_3': {'format': 'text', 'tags': ['plain-text']},
      });

      final corpus = FixtureCorpus.load(dir);

      expect(corpus.fixtures.map((f) => f.name), ['eml_2', 'eml_3', 'eml_10']);
      expect(corpus.byName('eml_10').tags, {'quotes'});
      expect(corpus.byName('eml_3').format, FixtureFormat.text);
      expect(corpus.byName('eml_2').read(), '<p>two</p>');
      expect(corpus.withTag('quotes').single.name, 'eml_10');
      expect(corpus.withFormat(FixtureFormat.text).single.name, 'eml_3');
    });

    test('SHOULD ignore files that are not fixtures', () {
      final dir = writeCorpus(temp, files: {'eml_1.html.gz': 'a'}, manifestFixtures: {
        'eml_1': {'format': 'html'},
      });
      File('${dir.path}/README.md').writeAsStringSync('notes');

      expect(FixtureCorpus.load(dir).fixtures, hasLength(1));
    });

    for (final MapEntry(key: condition, value: corpus) in _inconsistentCorpora.entries) {
      test('SHOULD fail WHEN $condition', () => _expectInconsistent(temp, corpus));
    }

    test('SHOULD fail WHEN a manifest entry has an unknown key', () {
      final dir = writeCorpus(temp, files: {'eml_1.html.gz': 'a'}, manifestFixtures: {
        'eml_1': {'format': 'html', 'tag': ['quotes']},
      });

      expect(
        () => FixtureCorpus.load(dir),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('unknown manifest keys {tag}'))),
      );
    });

    test('SHOULD fail WHEN the manifest schema version is unknown', () {
      final dir = writeCorpus(temp, files: {}, manifestFixtures: {}, schemaVersion: 2);

      expect(() => FixtureCorpus.load(dir), throwsFormatException);
    });

    test('SHOULD fail WHEN byName is given an unknown fixture', () {
      final dir = writeCorpus(temp, files: {}, manifestFixtures: {});

      expect(() => FixtureCorpus.load(dir).byName('eml_1'), throwsArgumentError);
    });
  });
}
