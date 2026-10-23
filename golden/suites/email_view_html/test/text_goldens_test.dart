import 'package:golden_email_view_html/golden_email_view_html.dart';
import 'package:golden_kit/golden_kit.dart';

/// The sanitizer text transformer runs before the DOM transformers and
/// already strips `<script>` and `<button>`; these DOM transformers stay as
/// defense in depth, and the composer suite (no sanitizer) exercises them.
const _scriptReason = 'StandardizeHtmlSanitizingTransformers removes <script> first';
const _buttonReason = 'StandardizeHtmlSanitizingTransformers removes <button> first';

const _coveredBySanitizer = {
  'preview-native/without RemoveScriptTransformer': _scriptReason,
  'preview-web/without RemoveScriptTransformer': _scriptReason,
  'preview-native/without RemoveCollapsedSignatureButtonTransformer': _buttonReason,
  'preview-web/without RemoveCollapsedSignatureButtonTransformer': _buttonReason,
};

/// Text snapshots and transformer mutants of the email view pipelines.
/// Update snapshots with `GOLDEN_UPDATE=1 flutter test`.
void main() {
  final layout = GoldenLayout.current();
  final suite = TextGoldenSuite(
    layout: layout,
    corpus: layout.corpus('emails'),
    pipelines: EmailViewPipelines().all,
  );

  defineTextGoldenTests(suite);
  defineMutationTests(MutationSuite(suite, explainedSurvivors: _coveredBySanitizer));
}
