import 'package:golden_composer_html/golden_composer_html.dart';
import 'package:golden_kit/golden_kit.dart';

/// Text snapshots and transformer mutants of the composer_html pipelines.
/// Update snapshots with `GOLDEN_UPDATE=1 flutter test`.
void main() {
  final layout = GoldenLayout.current();
  final suite = TextGoldenSuite(layout: layout, corpus: layout.corpus('emails'), pipelines: composerPipelines());

  defineTextGoldenTests(suite);
  defineMutationTests(MutationSuite(suite));
}
