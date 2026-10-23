import 'package:golden_kit/golden_kit.dart';
import 'package:golden_tmail_html/golden_tmail_html.dart';

/// The pipelines whose output the email viewers show.
class EmailViewPipelines {
  EmailViewPipelines([TmailPipelines? pipelines]) : _pipelines = pipelines ?? TmailPipelines();

  final TmailPipelines _pipelines;

  List<TextPipeline> get all => [_pipelines.previewNative, _pipelines.previewWeb, _pipelines.plainText];

  /// The pipeline whose output [fixture] shows in a web or native viewer.
  TextPipeline forFixture(Fixture fixture, {required bool web}) => switch (fixture.format) {
        FixtureFormat.text => _pipelines.plainText,
        FixtureFormat.html => web ? _pipelines.previewWeb : _pipelines.previewNative,
      };
}
