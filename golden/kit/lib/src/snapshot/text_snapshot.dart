import 'dart:io';
import 'dart:math' as math;

import 'package:golden_kit/src/snapshot/golden_mode.dart';
import 'package:golden_kit/src/snapshot/snapshot_store.dart';

/// Compares text output with its stored snapshot.
///
/// On a mismatch the actual text is written under [diffDirectory] so the full
/// diff can be opened (`git diff --no-index <expected> <actual>`) and uploaded
/// by CI, and the failure message shows the first differing lines.
class TextSnapshotVerifier {
  const TextSnapshotVerifier({
    required this.store,
    required this.diffDirectory,
    this.mode = GoldenMode.verify,
    this.updateCommand = 'GOLDEN_UPDATE=1 flutter test',
  });

  static const _contextLines = 3;

  final SnapshotStore store;
  final Directory diffDirectory;
  final GoldenMode mode;
  final String updateCommand;

  /// Returns null when [actual] matches, otherwise the failure message.
  String? verify(SnapshotKey key, String actual) {
    if (mode == GoldenMode.update) {
      store.write(key, actual);
      return null;
    }
    final expected = store.read(key);
    if (expected == null) {
      return '$key has no snapshot at ${store.describe(key)}.\nCreate it with: $updateCommand';
    }
    if (expected == actual) return null;
    final actualFile = File('${diffDirectory.path}/${key.path}.actual')
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
    return [
      '$key changed.',
      'expected: ${store.describe(key)}',
      'actual:   ${actualFile.path}',
      _firstDifference(expected, actual),
      'If the change is intended, update with: $updateCommand',
    ].join('\n');
  }

  /// Snapshots stored for keys the suite no longer produces.
  Set<SnapshotKey> orphans(Set<SnapshotKey> produced) => store.keys().difference(produced);

  /// Deletes orphans in update mode; returns the failure message otherwise.
  String? pruneOrReport(Set<SnapshotKey> produced) {
    final stale = orphans(produced);
    if (stale.isEmpty) return null;
    if (mode == GoldenMode.update) {
      stale.forEach(store.delete);
      return null;
    }
    final paths = (stale.map((key) => key.path).toList()..sort()).join('\n  ');
    return 'Stored snapshots no case produces any more:\n  $paths\nDelete them with: $updateCommand';
  }

  static String _firstDifference(String expected, String actual) {
    final expectedLines = expected.split('\n');
    final actualLines = actual.split('\n');
    final index = _commonPrefixLength(expectedLines, actualLines);
    final column = _commonPrefixLength(
      _lineAt(expectedLines, index).codeUnits,
      _lineAt(actualLines, index).codeUnits,
    );
    final from = index - _contextLines < 0 ? 0 : index - _contextLines;
    String excerpt(List<String> lines, String marker) {
      final to = index + _contextLines + 1 > lines.length ? lines.length : index + _contextLines + 1;
      return [
        for (var i = from; i < to; i++)
          i == index
              ? '$marker ${i + 1}:${column + 1}: ${_window(lines[i], column)}'
              : '  ${i + 1}: ${_window(lines[i], 0)}',
      ].join('\n');
    }

    return 'first difference at line ${index + 1}, column ${column + 1} '
        '(expected ${expectedLines.length} lines, actual ${actualLines.length}):\n'
        '--- expected\n${excerpt(expectedLines, '-')}\n'
        '+++ actual\n${excerpt(actualLines, '+')}';
  }

  static int _commonPrefixLength<T>(List<T> a, List<T> b) {
    final limit = math.min(a.length, b.length);
    var length = 0;
    while (length < limit && a[length] == b[length]) {
      length++;
    }
    return length;
  }

  static String _lineAt(List<String> lines, int index) => index < lines.length ? lines[index] : '';

  /// At most 160 characters of [line], starting a little before [column].
  static String _window(String line, int column) {
    const before = 40;
    const width = 160;
    final start = column - before < 0 ? 0 : column - before;
    final end = start + width > line.length ? line.length : start + width;
    return '${start > 0 ? '…' : ''}${line.substring(start, end)}${end < line.length ? '…' : ''}';
  }
}
