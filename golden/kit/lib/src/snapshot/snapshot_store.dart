/// Identifies one stored snapshot inside a store, e.g. `preview-web/eml_12`.
class SnapshotKey {
  SnapshotKey(List<String> segments) : segments = List.unmodifiable(segments) {
    if (!segments.every(_isPlainName)) {
      throw ArgumentError.value(segments, 'segments', 'each segment must be a plain name');
    }
  }

  static bool _isPlainName(String segment) {
    if (segment.isEmpty || segment == '..') return false;
    return !segment.contains('/') && !segment.contains('\\');
  }

  final List<String> segments;

  String get path => segments.join('/');

  @override
  bool operator ==(Object other) => other is SnapshotKey && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => path;
}

/// Where snapshots of one kind live. Implementations decide the encoding.
abstract interface class SnapshotStore {
  /// The stored content, or null when the snapshot does not exist.
  String? read(SnapshotKey key);

  /// Stores [content]; returns false when the stored content was already equal.
  bool write(SnapshotKey key, String content);

  void delete(SnapshotKey key);

  /// Every key currently stored.
  Set<SnapshotKey> keys();

  /// Human-readable location of [key], for failure messages.
  String describe(SnapshotKey key);
}
