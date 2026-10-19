import '../models/test_tags.dart';

/// The tags of one Gherkin scenario, checked against
/// docs/testing/gherkin-conventions.md.
///
/// Pure Dart: the feature-file guard in `test/` runs it without a device.
class ScenarioMetadata {
  /// Added to every scenario, so `--tags=gherkin` selects all of them.
  static const gherkinTag = 'gherkin';

  static const groupTags = {'smoke'};

  final String id;
  final String priority;
  final List<TestTags> platforms;
  final List<String> groups;

  /// Regression sources such as `pr-4539` or `issue-4488`.
  final List<String> sources;
  final DateTime? verifiedOn;

  const ScenarioMetadata._({
    required this.id,
    required this.priority,
    required this.platforms,
    required this.groups,
    required this.sources,
    required this.verifiedOn,
  });

  /// Throws a [FormatException] listing every problem in [tags].
  ///
  /// Tags may be written with or without the leading `@`. [today] bounds
  /// `@verified` dates and defaults to the current date.
  factory ScenarioMetadata.parse(Iterable<String> tags, {DateTime? today}) {
    final parser = _ScenarioTagParser(today ?? DateTime.now());
    for (final tag in tags) {
      parser.add(tag.startsWith('@') ? tag.substring(1) : tag);
    }
    return parser.build();
  }

  /// Tags handed to Patrol for `--tags` selection. `key:value` metadata is
  /// left out: test_api only accepts hyphenated identifiers as tags.
  List<String> get selectableTags => [
        gherkinTag,
        id,
        priority,
        ...platforms.map((platform) => platform.name),
        ...groups,
      ];
}

class _ScenarioTagParser {
  static final _idPattern = RegExp(r'^NR-[A-Z][A-Z0-9]*-\d{3}$');
  static final _priorityPattern = RegExp(r'^P[1-3]$');
  static final _sourcePattern = RegExp(r'^src:(?:pr|issue)-[1-9]\d*$');
  static final _verifiedPattern = RegExp(r'^verified:(\d{4})-(\d{2})-(\d{2})$');
  static final _platformsByName = TestTags.values.asNameMap();

  final DateTime _today;
  final _ids = <String>[];
  final _priorities = <String>[];
  final _platforms = <TestTags>[];
  final _groups = <String>[];
  final _sources = <String>[];
  final _verifiedDates = <DateTime>[];
  final _problems = <String>[];

  _ScenarioTagParser(DateTime today)
      : _today = DateTime.utc(today.year, today.month, today.day);

  void add(String tag) {
    final platform = _platformsByName[tag];
    if (_idPattern.hasMatch(tag)) {
      _ids.add(tag);
    } else if (_priorityPattern.hasMatch(tag)) {
      _priorities.add(tag);
    } else if (platform != null) {
      _platforms.add(platform);
    } else if (ScenarioMetadata.groupTags.contains(tag)) {
      _groups.add(tag);
    } else if (_sourcePattern.hasMatch(tag)) {
      _sources.add(tag.substring('src:'.length));
    } else if (tag.startsWith('verified:')) {
      _addVerified(tag);
    } else {
      _problems.add('unknown tag @$tag');
    }
  }

  void _addVerified(String tag) {
    final match = _verifiedPattern.firstMatch(tag);
    final date = match == null ? null : _validDate(match);
    if (date == null) {
      _problems.add('@$tag is not a valid YYYY-MM-DD date');
    } else if (date.isAfter(_today)) {
      _problems.add('@$tag is in the future');
    } else {
      _verifiedDates.add(date);
    }
  }

  /// Null when the digits name no real day (e.g. 2026-02-30).
  DateTime? _validDate(RegExpMatch match) {
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime.utc(year, month, day);
    return date.month == month && date.day == day ? date : null;
  }

  ScenarioMetadata build() {
    _expectOne(_ids, 'id @NR-<AREA>-<NNN>');
    _expectOne(_priorities, 'priority @P1, @P2 or @P3');
    if (_platforms.isEmpty) {
      _problems.add('missing platform @android, @ios or @web');
    }
    if (_verifiedDates.length > 1) {
      _problems.add('more than one @verified date');
    }
    if (_problems.isNotEmpty) {
      throw FormatException('Invalid scenario tags: ${_problems.join('; ')}');
    }
    return ScenarioMetadata._(
      id: _ids.single,
      priority: _priorities.single,
      platforms: List.unmodifiable(_platforms),
      groups: List.unmodifiable(_groups),
      sources: List.unmodifiable(_sources),
      verifiedOn: _verifiedDates.firstOrNull,
    );
  }

  void _expectOne(List<String> found, String description) {
    if (found.isEmpty) {
      _problems.add('missing $description');
    } else if (found.length > 1) {
      _problems.add('more than one $description: ${found.join(', ')}');
    }
  }
}
