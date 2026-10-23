import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

RenderCase renderCase({String state = 'collapsed', String document = 'web/1000/ltr/eml_1.html'}) => RenderCase(
      target: 'web',
      fixture: 'eml_1',
      width: 1000,
      state: state,
      direction: 'ltr',
      document: document,
      policy: const FixturePolicy(allowHorizontalOverflow: {'web'}),
    );

void main() {
  group('withoutPart', () {
    test('SHOULD remove the first occurrence of the part', () {
      expect(withoutPart('a<s>b<s>', '<s>', mutantId: 'm'), 'ab<s>');
    });

    for (final part in ['', '<missing>']) {
      test('SHOULD fail loudly WHEN the part "$part" is not in the document', () {
        expect(() => withoutPart('abc', part, mutantId: 'm'), throwsStateError);
      });
    }
  });

  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('export_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  group('RenderExportWriter', () {
    test('SHOULD write documents, assets and a versioned cases.json for the suite', () {
      final asset = File('${temp.path}/font.ttf')..writeAsStringSync('font');
      final writer = RenderExportWriter(temp, 'email_view_html')
        ..writeDocument('web/1000/ltr/eml_1.html', '<html></html>')
        ..copyAsset('web/assets/font.ttf', asset)
        ..addCase(renderCase())
        ..addCase(renderCase(state: 'expanded'))
        ..finish();

      final dir = '${temp.path}/email_view_html';
      final json = jsonDecode(File('$dir/cases.json').readAsStringSync()) as Map<String, dynamic>;
      expect(writer.caseCount, 2);
      expect(File('$dir/web/1000/ltr/eml_1.html').readAsStringSync(), '<html></html>');
      expect(File('$dir/web/assets/font.ttf').readAsStringSync(), 'font');
      expect(json['schemaVersion'], 1);
      expect(json['suite'], 'email_view_html');
      expect((json['cases'] as List).first, {
        'id': 'web/1000/collapsed-ltr/eml_1',
        'target': 'web',
        'fixture': 'eml_1',
        'width': 1000,
        'state': 'collapsed',
        'direction': 'ltr',
        'document': 'web/1000/ltr/eml_1.html',
        'policy': const FixturePolicy(allowHorizontalOverflow: {'web'}).toJson(),
      });
    });

    test('SHOULD write a mutant next to its case and list it in cases.json', () {
      final writer = RenderExportWriter(temp, 's')
        ..writeDocument('web/1000/ltr/eml_1.html', '<style>a</style><p>x</p>')
        ..addCase(renderCase());
      final path = writer.addMutant('without Quote Style', renderCase(), '<p>x</p>');
      writer.finish();

      expect(path, 'mutants/without-quote-style/web/1000/ltr/eml_1.html');

      final json = jsonDecode(File('${temp.path}/s/cases.json').readAsStringSync()) as Map<String, dynamic>;
      expect(json['mutants'], [
        {
          'id': 'without Quote Style',
          'cases': [
            {'caseId': 'web/1000/collapsed-ltr/eml_1', 'document': 'mutants/without-quote-style/web/1000/ltr/eml_1.html'},
          ],
        },
      ]);
      expect(File('${temp.path}/s/mutants/without-quote-style/web/1000/ltr/eml_1.html').readAsStringSync(), '<p>x</p>');
    });

    test('SHOULD reject a mutant of a case that was not added', () {
      final writer = RenderExportWriter(temp, 's');

      expect(() => writer.addMutant('m', renderCase(), ''), throwsArgumentError);
    });

    test('SHOULD clear a previous export of the same suite', () {
      File('${temp.path}/email_view_html/stale.html')
        ..createSync(recursive: true)
        ..writeAsStringSync('old');

      RenderExportWriter(temp, 'email_view_html');

      expect(File('${temp.path}/email_view_html/stale.html').existsSync(), isFalse);
    });

    test('SHOULD reject a case whose document was not written', () {
      final writer = RenderExportWriter(temp, 's');

      expect(() => writer.addCase(renderCase()), throwsArgumentError);
    });

    test('SHOULD reject a duplicate case', () {
      final writer = RenderExportWriter(temp, 's')
        ..writeDocument('web/1000/ltr/eml_1.html', '')
        ..addCase(renderCase());

      expect(() => writer.addCase(renderCase()), throwsArgumentError);
    });
  });
}
