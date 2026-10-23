import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

void main() {
  late Directory temp;
  late GzipFileSnapshotStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('store_test');
    store = GzipFileSnapshotStore(Directory('${temp.path}/text'), extension: 'html');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  group('SnapshotKey', () {
    test('SHOULD join segments into a path and compare by path', () {
      expect(SnapshotKey(['preview-web', 'eml_1']).path, 'preview-web/eml_1');
      expect(SnapshotKey(['a', 'b']), SnapshotKey(['a', 'b']));
    });

    for (final segment in ['', '..', 'a/b', r'a\b']) {
      test('SHOULD reject the segment "$segment"', () {
        expect(() => SnapshotKey(['ok', segment]), throwsArgumentError);
      });
    }
  });

  group('GzipFileSnapshotStore', () {
    final key = SnapshotKey(['preview-web', 'eml_1']);

    test('SHOULD return null for a missing snapshot', () {
      expect(store.read(key), isNull);
    });

    test('SHOULD read back what it wrote, stored as <root>/<key>.<ext>.gz', () {
      expect(store.write(key, '<p>é</p>'), isTrue);

      expect(store.read(key), '<p>é</p>');
      expect(File('${temp.path}/text/preview-web/eml_1.html.gz').existsSync(), isTrue);
      expect(store.describe(key), endsWith('text/preview-web/eml_1.html.gz'));
    });

    test('SHOULD NOT rewrite the file WHEN the content is unchanged', () {
      store.write(key, 'same');
      final file = File(store.describe(key));
      final before = file.readAsBytesSync();
      file.writeAsBytesSync([...before]);
      final stamp = file.lastModifiedSync();

      expect(store.write(key, 'same'), isFalse);
      expect(file.lastModifiedSync(), stamp);
    });

    test('SHOULD list stored keys and delete one', () {
      store.write(key, 'a');
      store.write(SnapshotKey(['print', 'eml_2']), 'b');
      File('${temp.path}/text/print/notes.txt').writeAsStringSync('ignored');

      expect(store.keys(), {key, SnapshotKey(['print', 'eml_2'])});

      store.delete(key);

      expect(store.keys(), {SnapshotKey(['print', 'eml_2'])});
    });

    test('SHOULD list no keys WHEN the root does not exist', () {
      expect(store.keys(), isEmpty);
    });
  });
}
