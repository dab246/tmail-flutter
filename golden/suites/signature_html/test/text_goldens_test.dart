import 'package:golden_signature_html/golden_signature_html.dart';
import 'package:golden_kit/golden_kit.dart';

/// The sanitizer text transformer runs first and already strips `<script>`.
const _scriptReason = 'StandardizeHtmlSanitizingTransformers removes <script> first';

const _explainedSurvivors = {
  'signature-identity/without RemoveScriptTransformer': _scriptReason,
};

/// Text snapshots and transformer mutants of the signature_html pipelines.
/// Update snapshots with `GOLDEN_UPDATE=1 flutter test`.
void main() {
  final layout = GoldenLayout.current();
  final suite = TextGoldenSuite(layout: layout, corpus: layout.corpus('signatures'), pipelines: signaturePipelines());

  defineTextGoldenTests(suite);
  defineMutationTests(MutationSuite(suite, explainedSurvivors: _explainedSurvivors));
}
