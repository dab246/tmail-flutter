import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';
import 'package:golden_tmail_html/golden_tmail_html.dart';

const _probe = '<p onclick="steal()">x</p><script>steal()</script><a href="javascript:steal()">y</a>';

Future<String?> _safetyOf(TextPipeline pipeline) async {
  final fixture = Fixture(name: 'probe', format: FixtureFormat.html, tags: const {}, file: File('unused'));
  final output = await pipeline.run(fixture, _probe);
  return const SafeHtmlInvariant().check(HtmlTransformSubject(
    fixture: fixture,
    input: _probe,
    output: output,
    policy: FixturePolicy.strict,
  ));
}

void main() {
  final pipelines = TmailPipelines();

  test('every pipeline SHOULD have a unique id', () {
    final ids = pipelines.all.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  for (final pipeline in pipelines.all.where((p) => p != pipelines.plainText)) {
    final claimsSafe = pipeline.invariants.any((i) => i is SafeHtmlInvariant);
    test('${pipeline.id} SHOULD ${claimsSafe ? '' : 'NOT '}remove scripts, handlers and javascript: URLs', () async {
      expect(await _safetyOf(pipeline), claimsSafe ? isNull : isNotNull);
    });
  }
}
