import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

void main() {
  late Directory temp;
  late GzipFileSnapshotStore store;
  final key = SnapshotKey(['preview-web', 'eml_1']);

  TextSnapshotVerifier verifier([GoldenMode mode = GoldenMode.verify]) => TextSnapshotVerifier(
        store: store,
        diffDirectory: Directory('${temp.path}/diff'),
        mode: mode,
        updateCommand: 'UPDATE',
      );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('verifier_test');
    store = GzipFileSnapshotStore(Directory('${temp.path}/text'), extension: 'html');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  group('TextSnapshotVerifier.verify', () {
    test('SHOULD pass WHEN the output equals the snapshot', () {
      store.write(key, 'a\nb');

      expect(verifier().verify(key, 'a\nb'), isNull);
    });

    test('SHOULD fail with the update command WHEN the snapshot is missing', () {
      final message = verifier().verify(key, 'a');

      expect(message, contains('has no snapshot'));
      expect(message, contains('UPDATE'));
      expect(store.read(key), isNull);
    });

    test('SHOULD report line and column of the first difference and write the actual output', () {
      store.write(key, 'same\n<p style="margin:0 0 0 .8ex">x</p>\nend');

      final message = verifier().verify(key, 'same\n<p style="margin:0">x</p>\nend')!;

      expect(message, contains('first difference at line 2, column 19'));
      expect(message, contains('- 2:19: <p style="margin:0 0 0 .8ex">x</p>'));
      expect(message, contains('+ 2:19: <p style="margin:0">x</p>'));
      expect(
        File('${temp.path}/diff/preview-web/eml_1.actual').readAsStringSync(),
        'same\n<p style="margin:0">x</p>\nend',
      );
    });

    test('SHOULD show a window around the difference on a very long line', () {
      final prefix = 'x' * 500;
      store.write(key, '${prefix}OLD');

      final message = verifier().verify(key, '${prefix}NEW')!;

      expect(message, contains('column 501'));
      expect(message, contains('xOLD'));
      expect(message, contains('xNEW'));
      expect(message.length, lessThan(1000));
    });

    test('SHOULD write the snapshot and pass in update mode', () {
      expect(verifier(GoldenMode.update).verify(key, 'new'), isNull);
      expect(store.read(key), 'new');
    });
  });

  group('TextSnapshotVerifier.pruneOrReport', () {
    final orphan = SnapshotKey(['print', 'eml_9']);

    setUp(() {
      store.write(key, 'a');
      store.write(orphan, 'b');
    });

    test('SHOULD report snapshots no case produces in verify mode', () {
      final message = verifier().pruneOrReport({key});

      expect(message, contains('print/eml_9'));
      expect(store.read(orphan), 'b');
    });

    test('SHOULD delete orphans in update mode', () {
      expect(verifier(GoldenMode.update).pruneOrReport({key}), isNull);
      expect(store.keys(), {key});
    });

    test('SHOULD pass WHEN every stored snapshot is produced', () {
      expect(verifier().pruneOrReport({key, orphan}), isNull);
    });
  });

  group('GoldenMode.fromEnvironment', () {
    test('SHOULD update only WHEN GOLDEN_UPDATE is 1', () {
      expect(GoldenMode.fromEnvironment({'GOLDEN_UPDATE': '1'}), GoldenMode.update);
      expect(GoldenMode.fromEnvironment({'GOLDEN_UPDATE': 'true'}), GoldenMode.verify);
      expect(GoldenMode.fromEnvironment({}), GoldenMode.verify);
    });
  });
}
