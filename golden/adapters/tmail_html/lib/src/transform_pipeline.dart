// Golden packages run only under `flutter test`, which is what the
// @visibleForTesting PlatformInfo.isTestingForWeb flag is for.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:core/presentation/utils/html_transformer/transform_configuration.dart';
import 'package:core/utils/platform_info.dart';
import 'package:golden_kit/golden_kit.dart';
import 'package:golden_tmail_html/src/offline_html_transform.dart';

typedef TransformConfigurationFactory = TransformConfiguration Function();

typedef FixtureFilter = bool Function(Fixture fixture);

typedef PlatformBody<T> = T Function();

/// The platform a configuration is built for. Some factories read
/// `PlatformInfo.isWeb` (e.g. `forEditDraftsEmail`), so the web variant is
/// built with `PlatformInfo.isTestingForWeb` flipped. Transformers only read
/// it for CID downloads, which offline fixtures never trigger, so the flag is
/// not needed while the transform runs.
enum PipelinePlatform {
  native,
  web;

  T during<T>(PlatformBody<T> body) {
    final previous = PlatformInfo.isTestingForWeb;
    PlatformInfo.isTestingForWeb = this == web;
    try {
      return body();
    } finally {
      PlatformInfo.isTestingForWeb = previous;
    }
  }
}

/// Body text, links and images survive; for pipelines that do not sanitize.
const preservingInvariants = <Invariant<HtmlTransformSubject>>[
  TextPreservedInvariant(),
  LinksAndImagesPreservedInvariant(),
];

/// [preservingInvariants], and the output runs no script.
const sanitizingInvariants = <Invariant<HtmlTransformSubject>>[
  ...preservingInvariants,
  SafeHtmlInvariant(),
];

/// One production `TransformConfiguration` factory applied to the fixtures
/// of one format: the exact code path a feature uses, with nothing rebuilt.
///
/// Its mutants drop one transformer each, read from the production factory,
/// so a transformer added to a configuration is mutated without any change
/// here.
class TransformPipeline implements MutablePipeline {
  TransformPipeline({
    required this.id,
    required this.format,
    required this.configuration,
    required this.invariants,
    this.platform = PipelinePlatform.native,
    FixtureFilter? where,
    OfflineHtmlTransform? transform,
  })  : _where = where,
        _transform = transform ?? OfflineHtmlTransform();

  @override
  final String id;

  final FixtureFormat format;
  final TransformConfigurationFactory configuration;
  final PipelinePlatform platform;
  final FixtureFilter? _where;
  final OfflineHtmlTransform _transform;

  @override
  final List<Invariant<HtmlTransformSubject>> invariants;

  @override
  Iterable<PipelineMutant> get mutants {
    final full = platform.during(configuration);
    return [
      for (var i = 0; i < full.domTransformers.length; i++)
        _mutant(full.domTransformers[i], () => _withoutDom(i)),
      for (var i = 0; i < full.textTransformers.length; i++)
        _mutant(full.textTransformers[i], () => _withoutText(i)),
    ];
  }

  @override
  bool accepts(Fixture fixture) => fixture.format == format && (_where?.call(fixture) ?? true);

  @override
  Future<String> run(Fixture fixture, String content) async {
    final config = platform.during(configuration);
    return switch (format) {
      FixtureFormat.html => _transform.html(content, config),
      FixtureFormat.text => _transform.text(content, config),
    };
  }

  PipelineMutant _mutant(Object removed, TransformConfigurationFactory configuration) => PipelineMutant(
        id: 'without ${removed.runtimeType}',
        pipeline: TransformPipeline(
          id: id,
          format: format,
          configuration: configuration,
          invariants: invariants,
          platform: platform,
          where: _where,
          transform: _transform,
        ),
      );

  TransformConfiguration _withoutDom(int index) {
    final full = configuration();
    return TransformConfiguration([...full.domTransformers]..removeAt(index), full.textTransformers);
  }

  TransformConfiguration _withoutText(int index) {
    final full = configuration();
    return TransformConfiguration(full.domTransformers, [...full.textTransformers]..removeAt(index));
  }
}
