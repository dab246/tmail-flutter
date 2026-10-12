@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_email_view_html/golden_email_view_html.dart';
import 'package:golden_kit/golden_kit.dart';

/// Export step of the pixel goldens; runs only under `golden/run.sh`.
void main() {
  final layout = GoldenLayout.current();
  defineRenderExport(EmailViewRenderSuite(
    corpus: layout.corpus('emails'),
    policies: layout.policies,
    webFonts: _designFonts(),
  ));
}

List<File> _designFonts() {
  final fonts = Directory('${packageRoot('linagora_design_flutter').path}/assets/fonts');
  return fonts.listSync().whereType<File>().where((f) => f.path.endsWith('.ttf')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}
