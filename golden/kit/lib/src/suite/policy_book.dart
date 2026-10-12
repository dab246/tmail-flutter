import 'dart:convert';
import 'dart:io';

/// What one suite accepts for one fixture, where it deviates from the strict
/// default. The corpus describes content; expectations belong to the suite.
class FixturePolicy {
  const FixturePolicy({
    this.maxMissingTextTokens = 0,
    this.maxLostLinks = 0,
    this.maxLostImages = 0,
    this.allowHorizontalOverflow = const {},
    this.skipPixel,
  });

  static const strict = FixturePolicy();

  static const keys = {
    'maxMissingTextTokens',
    'maxLostLinks',
    'maxLostImages',
    'allowHorizontalOverflow',
    'skipPixel',
  };

  /// Body text tokens of the input that may be absent from the output.
  final int maxMissingTextTokens;
  final int maxLostLinks;
  final int maxLostImages;

  /// Render targets on which the page may scroll horizontally.
  final Set<String> allowHorizontalOverflow;

  /// Reason to skip the pixel comparison (quarantine); null when compared.
  final String? skipPixel;

  factory FixturePolicy.fromJson(Map<String, dynamic> json, {FixturePolicy base = strict}) =>
      FixturePolicy(
        maxMissingTextTokens: json['maxMissingTextTokens'] as int? ?? base.maxMissingTextTokens,
        maxLostLinks: json['maxLostLinks'] as int? ?? base.maxLostLinks,
        maxLostImages: json['maxLostImages'] as int? ?? base.maxLostImages,
        allowHorizontalOverflow: (json['allowHorizontalOverflow'] as List<dynamic>?)
                ?.cast<String>()
                .toSet() ??
            base.allowHorizontalOverflow,
        skipPixel: json['skipPixel'] as String? ?? base.skipPixel,
      );

  Map<String, Object?> toJson() => {
        'maxMissingTextTokens': maxMissingTextTokens,
        'maxLostLinks': maxLostLinks,
        'maxLostImages': maxLostImages,
        'allowHorizontalOverflow': allowHorizontalOverflow.toList()..sort(),
        'skipPixel': skipPixel,
      };
}

/// A suite's `policies.json`:
///
/// ```json
/// {
///   "eml_7": {
///     "reason": "wide newsletter table scrolls on web by design",
///     "allowHorizontalOverflow": ["web"],
///     "pipelines": { "print": { "maxLostImages": 1 } }
///   }
/// }
/// ```
///
/// Every entry needs a `reason`, so no deviation is accepted silently.
class PolicyBook {
  PolicyBook._(this._entries);

  final Map<String, Map<String, dynamic>> _entries;

  static final empty = PolicyBook._(const {});

  static const _entryKeys = {...FixturePolicy.keys, 'reason', 'pipelines'};

  factory PolicyBook.load(File file) {
    if (!file.existsSync()) return empty;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final entries = json.map((name, value) => MapEntry(name, value as Map<String, dynamic>));
    final errors = [
      for (final MapEntry(key: name, value: entry) in entries.entries) ..._entryErrors(name, entry),
    ];
    if (errors.isNotEmpty) {
      throw FormatException('${file.path}:\n${errors.join('\n')}');
    }
    return PolicyBook._(entries);
  }

  /// Unknown keys are typos that would silently loosen nothing; reject them.
  static Iterable<String> _entryErrors(String name, Map<String, dynamic> entry) => [
        if ((entry['reason'] as String? ?? '').trim().isEmpty) '$name: every policy needs a "reason"',
        for (final key in entry.keys.toSet().difference(_entryKeys)) '$name: unknown key "$key"',
        for (final MapEntry(key: pipeline, value: override) in _overrides(entry).entries)
          for (final key in (override as Map<String, dynamic>).keys.toSet().difference(FixturePolicy.keys))
            '$name.pipelines.$pipeline: unknown key "$key"',
      ];

  static Map<String, dynamic> _overrides(Map<String, dynamic> entry) =>
      entry['pipelines'] as Map<String, dynamic>? ?? const {};

  Set<String> get fixtureNames => _entries.keys.toSet();

  /// Pipelines named in overrides, to check they exist in the suite.
  Set<String> get pipelineNames => {for (final entry in _entries.values) ..._overrides(entry).keys};

  FixturePolicy forFixture(String fixture, {String? pipeline}) {
    final entry = _entries[fixture];
    if (entry == null) return FixturePolicy.strict;
    final general = FixturePolicy.fromJson(entry);
    final override = _overrides(entry)[pipeline];
    return override is Map<String, dynamic> ? FixturePolicy.fromJson(override, base: general) : general;
  }
}
