/// Golden suite for signature HTML.
library;

import 'package:golden_kit/golden_kit.dart';
import 'package:golden_tmail_html/golden_tmail_html.dart';

/// Identity settings (sanitized) and composer insertion (normalized only).
List<TextPipeline> signaturePipelines([TmailPipelines? pipelines]) {
  final p = pipelines ?? TmailPipelines();
  return [p.signatureIdentity, p.composerSignature];
}
