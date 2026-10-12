import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

import '../support/temp_corpus.dart';

typedef _Transform = String Function(String content);

/// Uppercases, then appends a marker; each part can be removed.
class _FakePipeline implements MutablePipeline {
  _FakePipeline(this.parts, {this.id = 'fake'});

  @override
  final String id;
  final Map<String, _Transform> parts;
  int runs = 0;

  @override
  List<Invariant<HtmlTransformSubject>> get invariants => const [];

  @override
  bool accepts(Fixture fixture) => true;

  @override
  Future<String> run(Fixture fixture, String content) async {
    runs++;
    return parts.values.fold<String>(content, (text, part) => part(text));
  }

  @override
  Iterable<PipelineMutant> get mutants => [
        for (final name in parts.keys)
          PipelineMutant(
            id: 'without $name',
            pipeline: _FakePipeline({...parts}..remove(name), id: id),
          ),
      ];
}

MutationSuite _mutationSuite(Directory temp, _FakePipeline pipeline) {
  final corpus = FixtureCorpus.load(writeCorpus(temp, files: {
    'eml_1.html.gz': 'plain',
    'eml_2.html.gz': 'MARK',
  }, manifestFixtures: {
    'eml_1': {'format': 'html'},
    'eml_2': {'format': 'html'},
  }));
  return MutationSuite(TextGoldenSuite(
    layout: GoldenLayout(repositoryRoot: temp, suiteDirectory: temp),
    corpus: corpus,
    pipelines: [pipeline],
    policies: PolicyBook.empty,
  ));
}

Future<String?> _killerOf(MutationSuite suite, String mutantId) async {
  final (pipeline, mutant) = suite.mutants.firstWhere((m) => m.$2.id == mutantId);
  return (await suite.firstKillingFixture(pipeline, mutant))?.name;
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('mutation_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('SHOULD list one mutant per removable part, keyed by pipeline', () {
    final suite = _mutationSuite(temp, _FakePipeline({'upper': (t) => t.toUpperCase(), 'noop': (t) => t}));

    expect(suite.mutants.map((m) => MutationSuite.keyOf(m.$1, m.$2)), ['fake/without upper', 'fake/without noop']);
  });

  test('SHOULD find the fixture whose output a removed part changes', () async {
    final suite = _mutationSuite(temp, _FakePipeline({'upper': (t) => t.toUpperCase()}));

    expect(await _killerOf(suite, 'without upper'), 'eml_1');
  });

  test('SHOULD find no fixture WHEN the removed part changes nothing', () async {
    final suite = _mutationSuite(temp, _FakePipeline({'upper': (t) => t.toUpperCase(), 'noop': (t) => t}));

    expect(await _killerOf(suite, 'without noop'), isNull);
  });

  test('SHOULD run the original pipeline once per fixture for all mutants', () async {
    final pipeline = _FakePipeline({'a': (t) => t, 'b': (t) => t});
    final suite = _mutationSuite(temp, pipeline);

    for (final (original, mutant) in suite.mutants) {
      await suite.firstKillingFixture(original, mutant);
    }

    expect(pipeline.runs, 2);
  });
}
