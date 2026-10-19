import 'dart:io';

import 'package:cucumber_gherkin/cucumber_gherkin.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/gherkin/scenario_metadata.dart';

/// Checks the committed feature files against
/// docs/testing/gherkin-conventions.md, so a broken convention fails the
/// unit-test job instead of a later e2e run.
void main() {
  const featuresDir = 'integration_test/features';
  const stepsDir = '$featuresDir/steps';

  final featureFiles = Directory(featuresDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.feature'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('at least one feature file exists', () {
    expect(featureFiles, isNotEmpty);
  });

  final scenarioIds = <String, String>{};

  for (final file in featureFiles) {
    group(file.path, () {
      final envelopes = generateMessages(
        file.readAsStringSync(),
        file.path,
        const GherkinOptions(includeSource: false),
      );
      final parseErrors =
          envelopes.map((e) => e.parseError).nonNulls.map((e) => e.message);
      final feature = envelopes
          .map((e) => e.gherkinDocument)
          .nonNulls
          .firstOrNull
          ?.feature;
      final pickles = envelopes.map((e) => e.pickle).nonNulls;

      test('parses as Gherkin', () {
        expect(parseErrors, isEmpty);
        expect(feature, isNotNull, reason: 'no Feature: keyword');
      });

      test('sits directly under $featuresDir/<area>/', () {
        final relative = file.uri.pathSegments
            .skip(Uri.directory(featuresDir).pathSegments.length - 1)
            .toList();

        expect(relative, hasLength(2));
        expect(relative.first, isNot('steps'));
      });

      test('has no tags on Feature:, which Patrol cannot select by', () {
        expect(feature?.tags.map((tag) => tag.name), isEmpty);
      });

      for (final pickle in pickles) {
        test('scenario "${pickle.name}" has valid tags and a unique id', () {
          final metadata = ScenarioMetadata.parse(
            pickle.tags.map((tag) => tag.name),
          );
          // Every row of a Scenario Outline shares the outline's id.
          final scenario = '${file.path}#${pickle.astNodeIds.first}';
          final owner = scenarioIds.putIfAbsent(metadata.id, () => scenario);

          expect(owner, scenario, reason: '${metadata.id} is already used');
        });
      }
    });
  }

  // Patrol bundles every integration_test/**/*_test.dart as a test file, so a
  // helper named *_test.dart breaks the compilation of the whole e2e suite.
  test('every *_test.dart under integration_test declares main', () {
    final withoutMain = Directory('integration_test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('_test.dart'))
        .where((file) => !file.readAsStringSync().contains('void main('))
        .map((file) => file.path)
        .toList();

    expect(withoutMain, isEmpty);
  });

  test('every generated step stub has been implemented', () {
    final stubs = Directory(stepsDir).existsSync()
        ? Directory(stepsDir)
            .listSync()
            .whereType<File>()
            .where((file) => file.readAsStringSync().contains('UnimplementedError'))
            .map((file) => file.path)
            .toList()
        : <String>[];

    expect(stubs, isEmpty);
  });
}
