import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/src/corpus/natural_name.dart';

List<String> _sorted(List<String> names) =>
    (names.map(NaturalName.new).toList()..sort()).map((name) => name.value).toList();

void main() {
  group('NaturalName', () {
    test('SHOULD order names with the same prefix by their trailing number', () {
      expect(_sorted(['eml_10', 'eml_2', 'eml_1']), ['eml_1', 'eml_2', 'eml_10']);
    });

    test('SHOULD ignore leading zeros of the number and keep a lone zero', () {
      expect(_sorted(['eml_010', 'eml_9', 'eml_0']), ['eml_0', 'eml_9', 'eml_010']);
      expect(NaturalName('eml_007').number, '7');
      expect(NaturalName('eml_0').number, '0');
    });

    test('SHOULD fall back to plain order across prefixes or without numbers', () {
      expect(_sorted(['sig_1', 'eml_2', 'notes', 'eml']), ['eml', 'eml_2', 'notes', 'sig_1']);
    });

    test('SHOULD compare numbers longer than an int without overflow', () {
      expect(_sorted(['n_99999999999999999999', 'n_100000000000000000000']),
          ['n_99999999999999999999', 'n_100000000000000000000']);
    });
  });
}
