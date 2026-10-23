/// A property that must hold for every case, whatever the stored snapshot says.
///
/// A snapshot only tells that output changed; an invariant tells that it is
/// wrong, and still fails after a careless snapshot update.
abstract interface class Invariant<S> {
  String get id;

  /// Null when [subject] satisfies the invariant, otherwise why it does not.
  String? check(S subject);
}
