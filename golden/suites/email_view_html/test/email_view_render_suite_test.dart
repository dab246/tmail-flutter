import 'dart:convert';
import 'dart:io';

import 'package:core/utils/html/html_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_email_view_html/golden_email_view_html.dart';
import 'package:golden_kit/golden_kit.dart';

const _fixtures = {
  'eml_1.html.gz': ('<p>hello</p>', <String>[]),
  'eml_2.html.gz': ('<p>reply</p><blockquote><p>original</p></blockquote>', ['responsive', 'rtl']),
  'eml_3.txt.gz': ('plain <b>text</b>', <String>[]),
};

FixtureCorpus _corpus(Directory temp) {
  final dir = Directory('${temp.path}/corpus')..createSync();
  final manifest = <String, Object>{};
  for (final MapEntry(key: file, value: (content, tags)) in _fixtures.entries) {
    File('${dir.path}/$file').writeAsBytesSync(gzip.encode(utf8.encode(content)));
    manifest[file.split('.').first] = {'format': file.contains('.txt') ? 'text' : 'html', 'tags': tags};
  }
  File('${dir.path}/manifest.json').writeAsStringSync(jsonEncode({'schemaVersion': 1, 'fixtures': manifest}));
  return FixtureCorpus.load(dir);
}

const _quoteStyleMutant = EmailViewMutant(
  id: 'without quote toggle style',
  part: _quoteStyle,
  targets: {EmailViewTarget.web},
  fixtureTag: 'responsive',
);

String _quoteStyle(EmailViewTarget target, EmailViewViewport viewport) => HtmlUtils.quoteToggleStyle;

String _missingPart(EmailViewTarget target, EmailViewViewport viewport) => '<script>not built</script>';

Future<List<Map<String, dynamic>>> _export(
  Directory temp, {
  PolicyBook? policies,
  List<EmailViewMutant> mutants = const [],
}) async {
  final font = File('${temp.path}/TwakeInter-Regular.ttf')..writeAsStringSync('font');
  final suite = EmailViewRenderSuite(
    corpus: _corpus(temp),
    policies: policies ?? PolicyBook.empty,
    webFonts: [font],
    mutants: mutants,
  );
  final writer = RenderExportWriter(Directory('${temp.path}/out'), suite.id);
  await suite.export(writer);
  writer.finish();
  return (_casesJson(temp)['cases'] as List).cast<Map<String, dynamic>>();
}

Map<String, dynamic> _casesJson(Directory temp) =>
    jsonDecode(File('${temp.path}/out/email_view_html/cases.json').readAsStringSync()) as Map<String, dynamic>;

Iterable<String> _ids(List<Map<String, dynamic>> cases, String fixture) =>
    cases.where((c) => c['fixture'] == fixture).map((c) => c['id'] as String);

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('email_view_export'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('SHOULD export one collapsed case per target for an untagged fixture', () async {
    final cases = await _export(temp);

    expect(_ids(cases, 'eml_1'), [
      'native-android/390/collapsed-ltr/eml_1',
      'native-ios/390/collapsed-ltr/eml_1',
      'web/1000/collapsed-ltr/eml_1',
      'ios-previewer/414/collapsed-ltr/eml_1',
    ]);
  });

  test('SHOULD add expanded, responsive and rtl cases from the fixture content and tags', () async {
    final ids = _ids(await _export(temp), 'eml_2').toSet();

    expect(ids, containsAll([
      'native-android/390/expanded-ltr/eml_2',
      'native-android/296/collapsed-ltr/eml_2',
      'native-android/744/expanded-ltr/eml_2',
      'native-android/390/collapsed-rtl/eml_2',
      'web/600/expanded-ltr/eml_2',
      'web/1400/collapsed-ltr/eml_2',
      'ios-previewer/320/collapsed-ltr/eml_2',
    ]));
    expect(ids.where((id) => id.startsWith('ios-previewer/') && id.contains('expanded')), isEmpty);
  });

  test('SHOULD render the web document from the web pipeline and copy fonts next to web documents only', () async {
    await _export(temp);
    final out = '${temp.path}/out/email_view_html';

    expect(File('$out/web/1032/ltr/eml_1.html').readAsStringSync(), contains('hello'));
    expect(File('$out/web/1032/ltr/${EmailViewRenderSuite.webFontPath}/TwakeInter-Regular.ttf').existsSync(), isTrue);
    expect(Directory('$out/native-android/414/ltr/assets').existsSync(), isFalse);
  });

  test('SHOULD render plain text fixtures through the plain text pipeline', () async {
    await _export(temp);

    final document = File('${temp.path}/out/email_view_html/native-ios/414/ltr/eml_3.html').readAsStringSync();
    expect(document, contains('&lt;b&gt;text&lt;/b&gt;'));
  });

  test('SHOULD attach the suite policy of the fixture to its cases', () async {
    final policies = File('${temp.path}/policies.json')
      ..writeAsStringSync(jsonEncode({
        'eml_1': {'reason': 'wide', 'allowHorizontalOverflow': ['web']},
      }));

    final cases = await _export(temp, policies: PolicyBook.load(policies));

    final policy = cases.firstWhere((c) => c['fixture'] == 'eml_1')['policy'] as Map<String, dynamic>;
    expect(policy['allowHorizontalOverflow'], ['web']);
  });

  test('SHOULD write a mutant without the part, with fonts, for matching standard cases only', () async {
    await _export(temp, mutants: [_quoteStyleMutant]);

    final mutants = _casesJson(temp)['mutants'] as List;
    final cases = (mutants.single as Map<String, dynamic>)['cases'] as List;
    expect(cases.map((c) => c['caseId']), ['web/1000/collapsed-ltr/eml_2']);
    final folder = '${temp.path}/out/email_view_html/mutants/without-quote-toggle-style/web/1032/ltr';
    expect(File('$folder/eml_2.html').readAsStringSync(), isNot(contains(HtmlUtils.quoteToggleStyle)));
    expect(File('$folder/${EmailViewRenderSuite.webFontPath}/TwakeInter-Regular.ttf').existsSync(), isTrue);
  });

  test('SHOULD fail loudly WHEN no case can show a mutant', () async {
    const unseen = EmailViewMutant(id: 'unseen', part: _quoteStyle, targets: {EmailViewTarget.web}, fixtureTag: 'none');

    await expectLater(_export(temp, mutants: [unseen]), throwsStateError);
  });

  test('SHOULD fail loudly WHEN the mutant part is no longer in the document', () async {
    const stale = EmailViewMutant(
      id: 'stale',
      part: _missingPart,
      targets: {EmailViewTarget.web},
      fixtureTag: 'responsive',
    );

    await expectLater(_export(temp, mutants: [stale]), throwsStateError);
  });

  test('every production mutant SHOULD find cases in the real corpus and remove a real part', () async {
    final layout = GoldenLayout.current();
    final suite = EmailViewRenderSuite(corpus: layout.corpus('emails'), policies: layout.policies, webFonts: const []);
    final writer = RenderExportWriter(Directory('${temp.path}/real'), suite.id);

    await suite.export(writer);
    writer.finish();

    final json = jsonDecode(File('${temp.path}/real/email_view_html/cases.json').readAsStringSync()) as Map<String, dynamic>;
    expect((json['mutants'] as List).map((m) => m['id']), emailViewMutants.map((m) => m.id));
  });
}
