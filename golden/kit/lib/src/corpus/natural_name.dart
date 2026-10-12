/// A fixture name split for natural ordering, so `eml_2` sorts before `eml_10`.
class NaturalName implements Comparable<NaturalName> {
  factory NaturalName(String value) {
    final digitsStart = _trailingDigitsStart(value);
    return NaturalName._(value, value.substring(0, digitsStart), _withoutLeadingZeros(value.substring(digitsStart)));
  }

  const NaturalName._(this.value, this.prefix, this.number);

  final String value;
  final String prefix;

  /// Trailing digits without leading zeros; empty when the name has none.
  final String number;

  @override
  int compareTo(NaturalName other) {
    if (prefix != other.prefix) return value.compareTo(other.value);
    if (number.isEmpty || other.number.isEmpty) return value.compareTo(other.value);
    final byLength = number.length.compareTo(other.number.length);
    return byLength != 0 ? byLength : number.compareTo(other.number);
  }

  static int _trailingDigitsStart(String value) {
    var start = value.length;
    while (start > 0 && _isDigit(value.codeUnitAt(start - 1))) {
      start--;
    }
    return start;
  }

  static String _withoutLeadingZeros(String digits) {
    var start = 0;
    while (start < digits.length - 1 && digits.codeUnitAt(start) == _zero) {
      start++;
    }
    return digits.substring(start);
  }

  static const _zero = 0x30;

  static bool _isDigit(int codeUnit) => codeUnit >= _zero && codeUnit <= 0x39;
}
