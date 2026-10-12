import 'dart:convert';
import 'dart:io';

import 'package:golden_kit/src/snapshot/snapshot_store.dart';

/// Stores each snapshot as `<root>/<segments>.<extension>.gz`.
///
/// Gzip keeps pull requests small; `.gitattributes` declares `diff=gzip` so a
/// local `git diff` with `gzip -dc` as textconv stays readable. A snapshot is
/// rewritten only when its text changed, so regenerating on another OS (whose
/// zlib writes different header bytes) does not churn unchanged files.
class GzipFileSnapshotStore implements SnapshotStore {
  GzipFileSnapshotStore(this.root, {required this.extension});

  final Directory root;

  /// Content extension without dot, e.g. `html`.
  final String extension;

  String get _suffix => '.$extension.gz';

  File _file(SnapshotKey key) => File('${root.path}/${key.path}$_suffix');

  @override
  String? read(SnapshotKey key) {
    final file = _file(key);
    if (!file.existsSync()) return null;
    return utf8.decode(gzip.decode(file.readAsBytesSync()));
  }

  @override
  bool write(SnapshotKey key, String content) {
    if (read(key) == content) return false;
    _file(key)
      ..createSync(recursive: true)
      ..writeAsBytesSync(gzip.encode(utf8.encode(content)));
    return true;
  }

  @override
  void delete(SnapshotKey key) {
    final file = _file(key);
    if (file.existsSync()) file.deleteSync();
  }

  @override
  Set<SnapshotKey> keys() {
    if (!root.existsSync()) return {};
    final rootPath = root.uri.path;
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith(_suffix))
        .map((file) {
      final relative = file.uri.path.substring(rootPath.length);
      return SnapshotKey(relative.substring(0, relative.length - _suffix.length).split('/'));
    }).toSet();
  }

  @override
  String describe(SnapshotKey key) => _file(key).path;
}
