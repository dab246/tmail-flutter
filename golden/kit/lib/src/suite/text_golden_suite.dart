import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/src/corpus/fixture.dart';
import 'package:golden_kit/src/corpus/fixture_corpus.dart';
import 'package:golden_kit/src/invariant/html_invariants.dart';
import 'package:golden_kit/src/invariant/invariant.dart';
import 'package:golden_kit/src/snapshot/golden_mode.dart';
import 'package:golden_kit/src/snapshot/gzip_file_snapshot_store.dart';
import 'package:golden_kit/src/snapshot/snapshot_store.dart';
import 'package:golden_kit/src/snapshot/text_snapshot.dart';
import 'package:golden_kit/src/suite/golden_layout.dart';
import 'package:golden_kit/src/suite/policy_book.dart';

/// One production code path that turns a fixture into HTML text.
abstract interface class TextPipeline {
  /// Snapshot folder name, e.g. `preview-web`.
  String get id;

  bool accepts(Fixture fixture);

  Future<String> run(Fixture fixture, String content);

  /// Checked on every output, independently of the stored snapshot.
  List<Invariant<HtmlTransformSubject>> get invariants;
}

/// Text snapshots of every accepted fixture × pipeline of one suite.
class TextGoldenSuite {
  TextGoldenSuite({
    required this.layout,
    required this.corpus,
    required this.pipelines,
    PolicyBook? policies,
  }) : policies = policies ?? layout.policies {
    final ids = pipelines.map((p) => p.id).toList();
    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(ids, 'pipelines', 'ids must be unique');
    }
  }

  final GoldenLayout layout;
  final FixtureCorpus corpus;
  final List<TextPipeline> pipelines;
  final PolicyBook policies;

  Iterable<(TextPipeline, Fixture)> get cases => [
        for (final pipeline in pipelines)
          for (final fixture in corpus.fixtures.where(pipeline.accepts)) (pipeline, fixture),
      ];

  SnapshotKey keyOf(TextPipeline pipeline, Fixture fixture) => SnapshotKey([pipeline.id, fixture.name]);

  /// Null when the case passes, otherwise every failure of the case.
  Future<String?> verify(TextPipeline pipeline, Fixture fixture, TextSnapshotVerifier verifier) async {
    final content = fixture.read();
    final output = await pipeline.run(fixture, content);
    final subject = HtmlTransformSubject(
      fixture: fixture,
      input: content,
      output: output,
      policy: policies.forFixture(fixture.name, pipeline: pipeline.id),
    );
    final failures = [
      verifier.verify(keyOf(pipeline, fixture), output),
      for (final invariant in pipeline.invariants)
        if (invariant.check(subject) case final message?) '[${invariant.id}] $message',
    ].nonNulls;
    return failures.isEmpty ? null : failures.join('\n\n');
  }
}

/// Registers one test per case, plus the corpus and policy consistency checks.
void defineTextGoldenTests(TextGoldenSuite suite, {GoldenMode? mode}) {
  final verifier = TextSnapshotVerifier(
    store: GzipFileSnapshotStore(suite.layout.textSnapshots, extension: 'html'),
    diffDirectory: suite.layout.diffDirectory,
    mode: mode ?? GoldenMode.fromEnvironment(),
    updateCommand: 'GOLDEN_UPDATE=1 flutter test (in ${suite.layout.suiteDirectory.path})',
  );

  group('${suite.layout.suiteId} text goldens', () {
    for (final (pipeline, fixture) in suite.cases) {
      test('${pipeline.id}/${fixture.name} SHOULD match its snapshot and invariants', () async {
        final failure = await suite.verify(pipeline, fixture, verifier);
        if (failure != null) fail(failure);
      });
    }

    test('every stored snapshot SHOULD still be produced by a case', () {
      final produced = suite.cases.map((c) => suite.keyOf(c.$1, c.$2)).toSet();
      final failure = verifier.pruneOrReport(produced);
      if (failure != null) fail(failure);
    });

    test('every policy SHOULD name a fixture of the corpus and pipelines of the suite', () {
      final fixtures = suite.corpus.fixtures.map((f) => f.name).toSet();
      final pipelines = suite.pipelines.map((p) => p.id).toSet();
      expect(suite.policies.fixtureNames.difference(fixtures), isEmpty, reason: 'unknown fixtures');
      expect(suite.policies.pipelineNames.difference(pipelines), isEmpty, reason: 'unknown pipelines');
    });
  });
}
