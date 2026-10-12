import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/src/export/document_mutation.dart';
import 'package:golden_kit/src/suite/policy_book.dart';

/// One screenshot the pixel runner takes: a document, the target that loads
/// it, and the state to put it in first.
class RenderCase {
  const RenderCase({
    required this.target,
    required this.fixture,
    required this.width,
    required this.state,
    required this.direction,
    required this.document,
    required this.policy,
  });

  final String target;
  final String fixture;
  final int width;

  /// Applied by the suite's Playwright plugin, e.g. `collapsed`, `expanded`.
  final String state;

  /// `ltr` or `rtl`.
  final String direction;

  /// Path of the document relative to the suite export folder.
  final String document;
  final FixturePolicy policy;

  /// Also the pixel golden path below `goldens/pixel/`.
  String get id => '$target/$width/$state-$direction/$fixture';

  Map<String, Object?> toJson() => {
        'id': id,
        'target': target,
        'fixture': fixture,
        'width': width,
        'state': state,
        'direction': direction,
        'document': document,
        'policy': policy.toJson(),
      };
}

/// Writes the contract between a Dart suite and the Playwright runner:
///
/// ```text
/// $GOLDEN_EXPORT_DIR/<suite>/cases.json   {schemaVersion, suite, cases[], mutants[]}
/// $GOLDEN_EXPORT_DIR/<suite>/<documents and assets>
/// $GOLDEN_EXPORT_DIR/<suite>/mutants/<mutant>/<documents>
/// ```
class RenderExportWriter {
  RenderExportWriter(Directory exportRoot, this.suiteId)
      : directory = Directory('${exportRoot.path}/$suiteId') {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);
  }

  static const schemaVersion = 1;
  static const environmentVariable = 'GOLDEN_EXPORT_DIR';

  final String suiteId;
  final Directory directory;
  final _cases = <String, RenderCase>{};
  final _documents = <String>{};
  final _mutants = <String, List<MutantCase>>{};

  /// Writes [html] once per [relativePath]; several cases may share it.
  void writeDocument(String relativePath, String html) {
    if (!_documents.add(relativePath)) return;
    File('${directory.path}/$relativePath')
      ..createSync(recursive: true)
      ..writeAsStringSync(html);
  }

  void copyAsset(String relativePath, File source) {
    final target = File('${directory.path}/$relativePath')..parent.createSync(recursive: true);
    source.copySync(target.path);
  }

  void addCase(RenderCase renderCase) {
    if (!_documents.contains(renderCase.document)) {
      throw ArgumentError('${renderCase.id}: document ${renderCase.document} was not written');
    }
    if (_cases.containsKey(renderCase.id)) {
      throw ArgumentError('duplicate case ${renderCase.id}');
    }
    _cases[renderCase.id] = renderCase;
  }

  /// Writes [document] as mutant [mutantId] of the already added [original];
  /// returns its path, next to which assets the document loads must go.
  String addMutant(String mutantId, RenderCase original, String document) {
    if (!_cases.containsKey(original.id)) {
      throw ArgumentError('mutant "$mutantId": case ${original.id} was not added');
    }
    final path = mutantDocumentPath(mutantId, original.document);
    writeDocument(path, document);
    _mutants.putIfAbsent(mutantId, () => []).add(MutantCase(caseId: original.id, document: path));
    return path;
  }

  int get caseCount => _cases.length;

  void finish() {
    File('${directory.path}/cases.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': schemaVersion,
        'suite': suiteId,
        'cases': _cases.values.map((c) => c.toJson()).toList(),
        'mutants': [
          for (final MapEntry(key: id, value: cases) in _mutants.entries)
            {'id': id, 'cases': cases.map((c) => c.toJson()).toList()},
        ],
      }),
    );
  }
}

/// A suite that has pixel goldens: it exports what the runner screenshots.
abstract interface class RenderGoldenSuite {
  String get id;

  Future<void> export(RenderExportWriter writer);
}

/// Registers the export step; skipped unless `GOLDEN_EXPORT_DIR` is set
/// (`golden/run.sh` sets it).
void defineRenderExport(RenderGoldenSuite suite, {Map<String, String>? environment}) {
  final exportRoot = (environment ?? Platform.environment)[RenderExportWriter.environmentVariable];
  test(
    '${suite.id} SHOULD export its render cases',
    () async {
      final writer = RenderExportWriter(Directory(exportRoot!), suite.id);
      await suite.export(writer);
      writer.finish();
      expect(writer.caseCount, greaterThan(0));
    },
    skip: exportRoot == null ? 'pixel export; run golden/run.sh' : false,
  );
}
