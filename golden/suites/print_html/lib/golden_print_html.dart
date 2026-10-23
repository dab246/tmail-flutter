/// Golden suite for the HTML `PrintFileDataSourceImpl` prints.
library;

import 'package:golden_kit/golden_kit.dart';
import 'package:golden_tmail_html/golden_tmail_html.dart';

/// Print applied to what the email view loaded, on native and web.
List<TextPipeline> printPipelines([TmailPipelines? pipelines]) {
  final p = pipelines ?? TmailPipelines();
  return [p.printFromPreviewNative, p.printFromPreviewWeb];
}
