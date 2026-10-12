import 'dart:io';

import 'package:golden_kit/src/corpus/fixture_corpus.dart';
import 'package:golden_kit/src/suite/policy_book.dart';

/// Where a suite's inputs and outputs live. Every suite has the same layout:
///
/// ```text
/// golden/corpus/<corpus>/            shared fixtures (data only)
/// golden/suites/<suite>/
///   suite.json                       id, kinds, trigger paths (read by CI)
///   policies.json                    per-fixture deviations, each with a reason
///   goldens/text/<pipeline>/...      text snapshots
///   goldens/pixel/<target>/...       pixel goldens (Playwright)
///   build/golden-diff/               actual output of failed cases (ignored)
/// ```
class GoldenLayout {
  GoldenLayout({required this.repositoryRoot, required this.suiteDirectory});

  /// The layout of the suite whose package is the working directory, which
  /// is where `flutter test` runs.
  factory GoldenLayout.current() {
    final suite = Directory.current.absolute;
    for (var dir = suite; dir.parent.path != dir.path; dir = dir.parent) {
      if (Directory('${dir.path}/golden/corpus').existsSync()) {
        return GoldenLayout(repositoryRoot: dir, suiteDirectory: suite);
      }
    }
    throw StateError('No golden/corpus above ${suite.path}');
  }

  final Directory repositoryRoot;
  final Directory suiteDirectory;

  String get suiteId => suiteDirectory.uri.pathSegments.where((s) => s.isNotEmpty).last;

  FixtureCorpus corpus(String name) =>
      FixtureCorpus.load(Directory('${repositoryRoot.path}/golden/corpus/$name'));

  PolicyBook get policies => PolicyBook.load(File('${suiteDirectory.path}/policies.json'));

  Directory get textSnapshots => Directory('${suiteDirectory.path}/goldens/text');

  Directory get diffDirectory => Directory('${suiteDirectory.path}/build/golden-diff');
}
