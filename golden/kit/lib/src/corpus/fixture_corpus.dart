import 'dart:convert';
import 'dart:io';

import 'package:golden_kit/src/corpus/fixture.dart';
import 'package:golden_kit/src/corpus/natural_name.dart';

/// A folder of gzipped fixtures described by its `manifest.json`.
///
/// The manifest lists every fixture with its format and content tags. Files
/// and manifest must match exactly, so a fixture is never added or removed
/// without being described.
class FixtureCorpus {
  FixtureCorpus._(this.directory, this.fixtures);

  static const manifestFileName = 'manifest.json';
  static const supportedSchemaVersion = 1;

  final Directory directory;

  /// Sorted by natural name order.
  final List<Fixture> fixtures;

  factory FixtureCorpus.load(Directory directory) {
    final manifest = _readManifest(directory);
    final files = _fixtureFiles(directory);
    final errors = [
      ..._unknownFileErrors(directory),
      ..._membershipErrors(manifest, files),
      ..._formatErrors(manifest, files),
    ];
    if (errors.isNotEmpty) {
      throw FormatException('Corpus ${directory.path} is inconsistent:\n${errors.join('\n')}');
    }
    final fixtures = [
      for (final MapEntry(key: name, value: stored) in files.entries)
        Fixture(name: name, format: stored.format, tags: manifest[name]!.tags, file: stored.file),
    ]..sort((a, b) => NaturalName(a.name).compareTo(NaturalName(b.name)));
    return FixtureCorpus._(directory, List.unmodifiable(fixtures));
  }

  Fixture byName(String name) => fixtures.firstWhere(
        (fixture) => fixture.name == name,
        orElse: () => throw ArgumentError.value(name, 'name', 'not in ${directory.path}'),
      );

  Iterable<Fixture> withFormat(FixtureFormat format) =>
      fixtures.where((fixture) => fixture.format == format);

  Iterable<Fixture> withTag(String tag) => fixtures.where((fixture) => fixture.hasTag(tag));

  /// A gzipped file with an unknown suffix is a typo, not a non-fixture.
  static Iterable<String> _unknownFileErrors(Directory directory) => [
        for (final file in directory.listSync().whereType<File>())
          if (_isUnknownGzip(file.uri.pathSegments.last))
            '${file.uri.pathSegments.last} is gzipped but not ${FixtureFormat.values.map((f) => '*${f.extension}').join(' or ')}',
      ];

  static bool _isUnknownGzip(String fileName) =>
      fileName.endsWith('.gz') && FixtureFormat.ofFile(fileName) == null;

  static Iterable<String> _membershipErrors(_Manifest manifest, _StoredFiles files) => [
        for (final name in files.keys.where((n) => !manifest.containsKey(n)))
          '$name is on disk but missing from $manifestFileName',
        for (final name in manifest.keys.where((n) => !files.containsKey(n)))
          '$name is in $manifestFileName but has no file',
      ];

  static Iterable<String> _formatErrors(_Manifest manifest, _StoredFiles files) => [
        for (final MapEntry(key: name, value: stored) in files.entries)
          if (manifest[name] case final entry? when entry.format != stored.format)
            '$name is declared ${entry.format.name} but stored as ${stored.format.name}',
      ];

  static _Manifest _readManifest(Directory directory) {
    final file = File('${directory.path}/$manifestFileName');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final version = json['schemaVersion'];
    if (version != supportedSchemaVersion) {
      throw FormatException('${file.path}: schemaVersion $version, expected $supportedSchemaVersion');
    }
    final entries = json['fixtures'] as Map<String, dynamic>;
    return entries.map((name, value) => MapEntry(name, _ManifestEntry.fromJson(name, value)));
  }

  static _StoredFiles _fixtureFiles(Directory directory) => {
        for (final file in directory.listSync().whereType<File>())
          if (_StoredFile.of(file) case final stored?) stored.name: stored,
      };
}

typedef _Manifest = Map<String, _ManifestEntry>;

typedef _StoredFiles = Map<String, _StoredFile>;

class _StoredFile {
  const _StoredFile(this.file, this.format, this.name);

  final File file;
  final FixtureFormat format;
  final String name;

  /// Null for files that are not fixtures (manifest, notes).
  static _StoredFile? of(File file) {
    final fileName = file.uri.pathSegments.last;
    final format = FixtureFormat.ofFile(fileName);
    if (format == null) return null;
    return _StoredFile(file, format, fileName.substring(0, fileName.length - format.extension.length));
  }
}

class _ManifestEntry {
  const _ManifestEntry(this.format, this.tags);

  final FixtureFormat format;
  final Set<String> tags;

  static const _keys = {'format', 'tags'};

  factory _ManifestEntry.fromJson(String name, Object? json) {
    if (json is! Map<String, dynamic>) {
      throw FormatException('$name: manifest entry must be an object');
    }
    final unknown = json.keys.toSet().difference(_keys);
    if (unknown.isNotEmpty) {
      throw FormatException('$name: unknown manifest keys $unknown');
    }
    final format = FixtureFormat.values.where((f) => f.name == json['format']).firstOrNull;
    if (format == null) {
      throw FormatException('$name: unknown format ${json['format']}');
    }
    final tags = (json['tags'] as List<dynamic>? ?? const []).cast<String>().toSet();
    return _ManifestEntry(format, tags);
  }
}
