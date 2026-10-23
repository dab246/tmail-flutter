import 'dart:io';

import 'package:core/presentation/utils/html_transformer/transform_configuration.dart';
import 'package:core/utils/platform_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';
import 'package:golden_tmail_html/golden_tmail_html.dart';

Fixture fixture(FixtureFormat format, {Set<String> tags = const {}}) =>
    Fixture(name: 'eml_1', format: format, tags: tags, file: File('unused'));

TransformPipeline _htmlPipeline({FixtureFilter? where}) => TransformPipeline(
      id: 'preview',
      format: FixtureFormat.html,
      configuration: TransformConfiguration.forPreviewEmail,
      invariants: sanitizingInvariants,
      where: where,
    );

void main() {
  tearDown(() => PlatformInfo.isTestingForWeb = false);

  group('TransformPipeline.accepts', () {
    final draftsOnly = _htmlPipeline(where: (f) => f.hasTag('draft'));

    test('SHOULD accept only fixtures of its format', () {
      expect(_htmlPipeline().accepts(fixture(FixtureFormat.html)), isTrue);
      expect(_htmlPipeline().accepts(fixture(FixtureFormat.text)), isFalse);
    });

    test('SHOULD also apply its fixture filter', () {
      expect(draftsOnly.accepts(fixture(FixtureFormat.html, tags: {'draft'})), isTrue);
      expect(draftsOnly.accepts(fixture(FixtureFormat.html)), isFalse);
    });
  });

  group('TransformPipeline.run', () {
    test('SHOULD run the production HTML transform offline', () async {
      final output = await _htmlPipeline().run(
        fixture(FixtureFormat.html),
        '<p onclick="x()">hi</p><script>alert(1)</script>',
      );

      expect(output, contains('hi'));
      expect(output, isNot(contains('onclick')));
      expect(output, isNot(contains('<script')));
    });

    test('SHOULD run the production plain text transform for text fixtures', () async {
      final pipeline = TransformPipeline(
        id: 'plain-text',
        format: FixtureFormat.text,
        configuration: TransformConfiguration.forPlainTextEmail,
        invariants: sanitizingInvariants,
      );

      final output = await pipeline.run(fixture(FixtureFormat.text), '<b>not markup</b>');

      expect(output, contains('&lt;b&gt;'));
    });

    test('SHOULD build the configuration as web and restore the platform afterwards', () async {
      bool? seenAsWeb;
      final pipeline = TransformPipeline(
        id: 'edit-drafts-web',
        format: FixtureFormat.html,
        platform: PipelinePlatform.web,
        configuration: () {
          seenAsWeb = PlatformInfo.isWeb;
          return TransformConfiguration.forEditDraftsEmail();
        },
        invariants: preservingInvariants,
      );

      await pipeline.run(fixture(FixtureFormat.html), '<p>x</p>');

      expect(seenAsWeb, isTrue);
      expect(PlatformInfo.isTestingForWeb, isFalse);
    });

    test('SHOULD restore the platform WHEN the run throws', () async {
      final pipeline = TransformPipeline(
        id: 'broken',
        format: FixtureFormat.html,
        platform: PipelinePlatform.web,
        configuration: () => throw StateError('boom'),
        invariants: const [],
      );

      await expectLater(pipeline.run(fixture(FixtureFormat.html), ''), throwsStateError);
      expect(PlatformInfo.isTestingForWeb, isFalse);
    });
  });

  group('TransformPipeline.mutants', () {
    test('SHOULD drop each transformer of the production configuration once', () async {
      final full = TransformConfiguration.forPreviewEmail();
      final mutants = _htmlPipeline().mutants.toList();

      expect(
        mutants.map((m) => m.id),
        [
          for (final t in [...full.domTransformers, ...full.textTransformers]) 'without ${t.runtimeType}',
        ],
      );
      final withoutSanitizer = mutants.last.pipeline;
      final output = await withoutSanitizer.run(fixture(FixtureFormat.html), '<p onclick="x()">hi</p>');
      expect(output, contains('onclick'));
    });

    test('SHOULD mutate the web variant of a platform-dependent configuration', () {
      PipelinePlatform.web.during(() => expect(PlatformInfo.isWeb, isTrue));
      final ids = TransformPipeline(
        id: 'edit-drafts-web',
        format: FixtureFormat.html,
        platform: PipelinePlatform.web,
        configuration: TransformConfiguration.forEditDraftsEmail,
        invariants: preservingInvariants,
      ).mutants.map((m) => m.id);

      expect(ids, contains('without HideDraftSignatureTransformer'));
      expect(PlatformInfo.isTestingForWeb, isFalse);
    });
  });
}
