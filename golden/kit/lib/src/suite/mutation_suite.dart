import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/src/corpus/fixture.dart';
import 'package:golden_kit/src/suite/text_golden_suite.dart';

/// A copy of a pipeline with one part removed, e.g. one transformer.
class PipelineMutant {
  const PipelineMutant({required this.id, required this.pipeline});

  /// What was removed, e.g. `without BlockQuotedTransformer`.
  final String id;
  final TextPipeline pipeline;
}

/// A pipeline made of parts that can be removed one at a time.
abstract interface class MutablePipeline implements TextPipeline {
  Iterable<PipelineMutant> get mutants;
}

/// Proves the goldens can fail: every part of every pipeline must change the
/// output of at least one fixture when removed. A part no fixture exercises
/// fails here with what to add, so a new transformer cannot merge untested
/// and a deleted one is caught by the snapshot it changes.
class MutationSuite {
  MutationSuite(this.suite, {Map<String, String> explainedSurvivors = const {}})
      : explainedSurvivors = Map.unmodifiable(explainedSurvivors);

  final TextGoldenSuite suite;

  /// Original output per `<pipeline>/<fixture>`, computed once for all its mutants.
  final _originals = <String, Future<String>>{};

  /// `<pipeline>/<mutant>` → why removing that part changes no fixture:
  /// intended redundancy (a later stage does the same work) or a known gap
  /// (the part is dead in production). The reason is shown as the skip note.
  final Map<String, String> explainedSurvivors;

  static String keyOf(TextPipeline pipeline, PipelineMutant mutant) => '${pipeline.id}/${mutant.id}';

  Iterable<(MutablePipeline, PipelineMutant)> get mutants => [
        for (final pipeline in suite.pipelines.whereType<MutablePipeline>())
          for (final mutant in pipeline.mutants) (pipeline, mutant),
      ];

  /// The first fixture whose output the mutant changes, or null.
  Future<Fixture?> firstKillingFixture(MutablePipeline pipeline, PipelineMutant mutant) async {
    for (final fixture in suite.corpus.fixtures.where(pipeline.accepts)) {
      final content = fixture.read();
      final original = await _originals.putIfAbsent(
        '${pipeline.id}/${fixture.name}',
        () => pipeline.run(fixture, content),
      );
      final mutated = await mutant.pipeline.run(fixture, content);
      if (original != mutated) return fixture;
    }
    return null;
  }
}

/// Registers one test per mutant, plus a check that every explained
/// survivor is still a mutant.
void defineMutationTests(MutationSuite mutation) {
  group('${mutation.suite.layout.suiteId} mutants', () {
    for (final (pipeline, mutant) in mutation.mutants) {
      final key = MutationSuite.keyOf(pipeline, mutant);
      final reason = mutation.explainedSurvivors[key];
      test(
        '$key SHOULD change at least one fixture',
        () => _expectKilled(mutation, pipeline, mutant),
        skip: reason == null ? false : 'survives: $reason',
      );
    }

    test('every explained survivor SHOULD still be a mutant', () {
      final existing = mutation.mutants.map((m) => MutationSuite.keyOf(m.$1, m.$2)).toSet();
      expect(mutation.explainedSurvivors.keys.toSet().difference(existing), isEmpty);
    });
  });
}

Future<void> _expectKilled(MutationSuite mutation, MutablePipeline pipeline, PipelineMutant mutant) async {
  final killer = await mutation.firstKillingFixture(pipeline, mutant);
  if (killer != null) return;
  fail(
    '${MutationSuite.keyOf(pipeline, mutant)} changes no fixture of '
    '${mutation.suite.corpus.directory.path}, so the goldens cannot catch a regression in it.\n'
    'Add a fixture that exercises it, or explain why it survives (intended redundancy or known gap).',
  );
}
