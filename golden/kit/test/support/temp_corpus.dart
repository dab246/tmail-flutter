import 'dart:convert';
import 'dart:io';

/// Writes a corpus folder with gzipped fixtures and a manifest.
Directory writeCorpus(
  Directory root, {
  required Map<String, String> files,
  required Map<String, Object?> manifestFixtures,
  int schemaVersion = 1,
}) {
  final dir = Directory('${root.path}/corpus')..createSync(recursive: true);
  for (final MapEntry(key: name, value: content) in files.entries) {
    File('${dir.path}/$name').writeAsBytesSync(gzip.encode(utf8.encode(content)));
  }
  File('${dir.path}/manifest.json').writeAsStringSync(
    jsonEncode({'schemaVersion': schemaVersion, 'fixtures': manifestFixtures}),
  );
  return dir;
}
