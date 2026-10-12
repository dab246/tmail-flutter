import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:golden_email_view_html/src/email_view_mutants.dart';
import 'package:golden_email_view_html/src/email_view_pipelines.dart';
import 'package:golden_email_view_html/src/email_view_target.dart';
import 'package:golden_kit/golden_kit.dart';

typedef RenderVariant = ({EmailViewViewport viewport, TextDirection direction});

/// A standard-viewport, left-to-right case kept to derive mutants from.
typedef _MutableCase = ({RenderCase renderCase, Fixture fixture, EmailViewTarget target, String document});

/// Manifest tags that add variants on top of the standard viewport, LTR.
abstract final class EmailViewTags {
  static const responsive = 'responsive';
  static const rtl = 'rtl';
}

/// Exports every fixture as each email viewer loads it, for the pixel runner.
class EmailViewRenderSuite implements RenderGoldenSuite {
  EmailViewRenderSuite({
    required this.corpus,
    required this.policies,
    required this.webFonts,
    EmailViewPipelines? pipelines,
    this.mutants = emailViewMutants,
  }) : pipelines = pipelines ?? EmailViewPipelines();

  static const suiteId = 'email_view_html';

  /// Marker of a quote toggle the viewer inserted into the document.
  static const quoteToggleMarker = '<button class="quote-toggle-button';

  /// Where the web document loads the design fonts from, relative to itself.
  static const webFontPath = 'assets/packages/linagora_design_flutter/assets/fonts';

  final FixtureCorpus corpus;
  final PolicyBook policies;

  /// Font files the web app serves; native viewers cannot load them.
  final List<File> webFonts;
  final EmailViewPipelines pipelines;
  final List<EmailViewMutant> mutants;

  final _mutableCases = <_MutableCase>[];

  /// Output per `<pipeline>/<fixture>`: several targets show the same output.
  final _outputs = <String, Future<String>>{};

  /// Folders that already hold the web fonts.
  final _fontFolders = <String>{};

  @override
  String get id => suiteId;

  @override
  Future<void> export(RenderExportWriter writer) async {
    for (final fixture in corpus.fixtures) {
      for (final target in EmailViewTarget.values) {
        await _exportOn(writer, fixture, target);
      }
    }
    for (final mutant in mutants) {
      _exportMutant(writer, mutant);
    }
  }

  /// The variants [fixture] is rendered in on any target.
  static List<RenderVariant> variantsOf(Fixture fixture, EmailViewTarget target) => [
        (viewport: target.standardViewport, direction: TextDirection.ltr),
        if (fixture.hasTag(EmailViewTags.responsive))
          for (final viewport in target.responsiveViewports) (viewport: viewport, direction: TextDirection.ltr),
        if (fixture.hasTag(EmailViewTags.rtl)) (viewport: target.standardViewport, direction: TextDirection.rtl),
      ];

  /// `collapsed` as opened; `expanded` too when the viewer added a toggle.
  static List<String> statesOf(EmailViewTarget target, String document) => [
        'collapsed',
        if (target.hasQuoteToggle && document.contains(quoteToggleMarker)) 'expanded',
      ];

  Future<void> _exportOn(RenderExportWriter writer, Fixture fixture, EmailViewTarget target) async {
    final pipeline = pipelines.forFixture(fixture, web: target.isWeb);
    final content = await _outputs.putIfAbsent(
      '${pipeline.id}/${fixture.name}',
      () => pipeline.run(fixture, fixture.read()),
    );
    final policy = policies.forFixture(fixture.name, pipeline: pipeline.id);
    final variants = variantsOf(fixture, target);
    for (final variant in variants) {
      final folder = '${target.label}/${variant.viewport.bodyWidth}/${variant.direction.name}';
      final document = target.buildDocument(content, variant.viewport, variant.direction);
      writer.writeDocument('$folder/${fixture.name}.html', document);
      if (target.isWeb) _copyWebFonts(writer, folder);
      for (final state in statesOf(target, document)) {
        final renderCase = RenderCase(
          target: target.label,
          fixture: fixture.name,
          width: target.paneWidth(variant.viewport),
          state: state,
          direction: variant.direction.name,
          document: '$folder/${fixture.name}.html',
          policy: policy,
        );
        writer.addCase(renderCase);
        if (variant == variants.first) {
          _mutableCases.add((renderCase: renderCase, fixture: fixture, target: target, document: document));
        }
      }
    }
  }

  /// Fails loudly when no case can show the mutant: a mutant that is never
  /// rendered would pass silently.
  void _exportMutant(RenderExportWriter writer, EmailViewMutant mutant) {
    final candidates = [
      for (final target in mutant.targets)
        ..._mutableCases.where((c) => c.target == target && _shows(mutant, c)).take(EmailViewMutant.maxCases),
    ];
    final unseenOn = mutant.targets.where((t) => !candidates.any((c) => c.target == t));
    if (unseenOn.isNotEmpty) {
      throw StateError('mutant "${mutant.id}": no ${mutant.state} case tagged ${mutant.fixtureTag} on $unseenOn');
    }
    for (final candidate in candidates) {
      final part = mutant.part(candidate.target, candidate.target.standardViewport);
      final path = writer.addMutant(
        mutant.id,
        candidate.renderCase,
        withoutPart(candidate.document, part, mutantId: mutant.id),
      );
      if (candidate.target.isWeb) _copyWebFonts(writer, path.substring(0, path.lastIndexOf('/')));
    }
  }

  static bool _shows(EmailViewMutant mutant, _MutableCase candidate) {
    if (!mutant.targets.contains(candidate.target)) return false;
    if (!candidate.fixture.hasTag(mutant.fixtureTag)) return false;
    return candidate.renderCase.state == mutant.state && _hasMarker(mutant, candidate.document);
  }

  static bool _hasMarker(EmailViewMutant mutant, String document) {
    final marker = mutant.requiredMarker;
    return marker == null || document.contains(marker);
  }

  void _copyWebFonts(RenderExportWriter writer, String folder) {
    if (!_fontFolders.add(folder)) return;
    for (final font in webFonts) {
      writer.copyAsset('$folder/$webFontPath/${font.uri.pathSegments.last}', font);
    }
  }
}
