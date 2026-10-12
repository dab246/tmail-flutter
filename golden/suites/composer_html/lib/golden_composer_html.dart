/// Golden suite for the HTML the composer loads into its editor.
library;

import 'package:golden_kit/golden_kit.dart';
import 'package:golden_tmail_html/golden_tmail_html.dart';

/// Reply, forward, drafts and restore content.
List<TextPipeline> composerPipelines([TmailPipelines? pipelines]) {
  final p = pipelines ?? TmailPipelines();
  return [p.replyForward, p.replyForwardEmpty, p.drafts, p.editDraftsNative, p.editDraftsWeb, p.restore];
}
