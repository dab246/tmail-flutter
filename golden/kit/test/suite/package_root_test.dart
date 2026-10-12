import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('package_root_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  void writeConfig(List<Map<String, String>> packages) =>
      File('${temp.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': packages}));

  test('SHOULD resolve a package root relative to the config found above the start folder', () {
    writeConfig([
      {'name': 'fonts', 'rootUri': '../vendor/fonts/'},
    ]);
    final nested = Directory('${temp.path}/a/b')..createSync(recursive: true);

    final root = packageRoot('fonts', from: nested);

    expect(root.absolute.uri.path, endsWith('/vendor/fonts/'));
    expect(root.absolute.path, startsWith(temp.absolute.path));
  });

  test('SHOULD fail WHEN the package is not in the config', () {
    writeConfig([]);

    expect(() => packageRoot('missing', from: temp), throwsStateError);
  });

  test('SHOULD resolve a real workspace package', () {
    expect(File('${packageRoot('golden_kit').path}/pubspec.yaml').existsSync(), isTrue);
  });
}
