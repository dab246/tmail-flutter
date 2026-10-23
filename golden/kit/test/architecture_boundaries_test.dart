import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

/// Dependency rules of the golden platform (docs/dev/plan/golden-testing/02):
/// production never sees golden code, the kit never sees production code, and
/// suites never see each other.
final _directive = RegExp(r"""^(?:import|export)\s+['"]([^'"]+)['"]""", multiLine: true);

Iterable<File> _dartFiles(Directory dir) => dir.existsSync()
    ? dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))
    : const [];

Iterable<(File, String)> _directives(Directory dir) sync* {
  for (final file in _dartFiles(dir)) {
    for (final match in _directive.allMatches(file.readAsStringSync())) {
      yield (file, match.group(1)!);
    }
  }
}

String _packageName(Directory dir) => File('${dir.path}/pubspec.yaml')
    .readAsLinesSync()
    .firstWhere((line) => line.startsWith('name:'))
    .substring('name:'.length)
    .trim();

void main() {
  final root = GoldenLayout.current().repositoryRoot;
  final golden = Directory('${root.path}/golden');

  List<Directory> packagesUnder(Directory dir) => dir.existsSync()
      ? (dir.listSync().whereType<Directory>().where((d) => File('${d.path}/pubspec.yaml').existsSync()).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : [];

  test('production code SHOULD NOT import any golden package', () {
    final productionLibs = [
      Directory('${root.path}/lib'),
      for (final package in packagesUnder(root)) Directory('${package.path}/lib'),
    ];
    final violations = [
      for (final lib in productionLibs)
        for (final (file, uri) in _directives(lib))
          if (uri.startsWith('package:golden_')) '${file.path} -> $uri',
    ];

    expect(violations, isEmpty);
  });

  test('golden_kit SHOULD depend only on the SDK and generic packages', () {
    const allowed = ['dart:', 'package:golden_kit/', 'package:flutter_test/', 'package:html/', 'package:collection/'];
    final violations = [
      for (final (file, uri) in _directives(Directory('${golden.path}/kit/lib')))
        if (!uri.startsWith('package:') && !uri.startsWith('dart:'))
          null
        else if (!allowed.any(uri.startsWith))
          '${file.path} -> $uri',
    ].nonNulls;

    expect(violations, isEmpty);
  });

  test('a suite SHOULD NOT import another suite', () {
    final suites = packagesUnder(Directory('${golden.path}/suites'));
    final names = {for (final suite in suites) suite: _packageName(suite)};
    final violations = [
      for (final suite in suites)
        for (final (file, uri) in _directives(suite))
          for (final other in names.values)
            if (other != names[suite] && uri.startsWith('package:$other/')) '${file.path} -> $uri',
    ];

    expect(suites, isNotEmpty);
    expect(violations, isEmpty);
  });
}
