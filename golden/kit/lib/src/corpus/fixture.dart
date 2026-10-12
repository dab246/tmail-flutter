import 'dart:convert';
import 'dart:io';

/// How a fixture's content must be read.
enum FixtureFormat {
  html('.html.gz'),
  text('.txt.gz');

  const FixtureFormat(this.extension);

  /// File name suffix of a fixture in this format.
  final String extension;

  static FixtureFormat? ofFile(String fileName) {
    for (final format in values) {
      if (fileName.endsWith(format.extension)) return format;
    }
    return null;
  }
}

/// One scrubbed input of a corpus, stored gzipped.
class Fixture {
  Fixture({
    required this.name,
    required this.format,
    required this.tags,
    required this.file,
  });

  final String name;
  final FixtureFormat format;
  final Set<String> tags;
  final File file;

  bool hasTag(String tag) => tags.contains(tag);

  /// Decoded once; suites read the same fixture for many pipelines.
  late final String _content = utf8.decode(gzip.decode(file.readAsBytesSync()));

  String read() => _content;

  @override
  String toString() => 'Fixture($name)';
}
