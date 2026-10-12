import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

HtmlTransformSubject subject(
  String input,
  String output, {
  FixtureFormat format = FixtureFormat.html,
  FixturePolicy policy = FixturePolicy.strict,
}) =>
    HtmlTransformSubject(
      fixture: Fixture(name: 'eml_1', format: format, tags: const {}, file: File('unused')),
      input: input,
      output: output,
      policy: policy,
    );

void _expectPassesWithin(
  Invariant<HtmlTransformSubject> invariant,
  String input,
  String output,
  FixturePolicy policy,
) {
  expect(invariant.check(subject(input, output)), isNotNull, reason: 'fails without the policy');
  expect(invariant.check(subject(input, output, policy: policy)), isNull);
}

void main() {
  group('TextPreservedInvariant', () {
    const invariant = TextPreservedInvariant();

    test('SHOULD pass WHEN every body word survives, whatever tags were added', () {
      expect(
        invariant.check(subject(
          '<p>see http://a.test now</p>',
          '<div><p>see <a href="http://a.test">http://a.test</a> now</p></div>',
        )),
        isNull,
      );
    });

    test('SHOULD keep a word whole WHEN an inline tag splits it, and split words at blocks', () {
      expect(
        invariant.check(subject(
          'From: Sam <sam@example.invalid>\nok',
          '<div>From: Sam &lt;<a href="mailto:sam@example.invalid">sam@example.invalid</a>&gt;</div><div>ok</div>',
          format: FixtureFormat.text,
        )),
        isNull,
      );
      expect(invariant.check(subject('<p>one</p><p>two</p>', '<p>onetwo</p>')), contains('2 text token(s)'));
    });

    test('SHOULD count hidden text and ignore head, style and script text', () {
      expect(
        invariant.check(subject(
          '<head><title>T</title><style>p{}</style></head><body><span style="display:none">pre</span>body<script>x()</script></body>',
          '<span style="display:none">pre</span>body',
        )),
        isNull,
      );
    });

    test('SHOULD fail with the lost words WHEN the pipeline drops text', () {
      final message = invariant.check(subject('<p>keep drop also</p>', '<p>keep</p>'));

      expect(message, contains('2 text token(s) of 3 lost'));
      expect(message, contains('"drop"'));
    });

    test('SHOULD count a repeated word as many times as it appears', () {
      expect(invariant.check(subject('<p>a a a</p>', '<p>a</p>')), contains('2 text token(s)'));
    });

    test('SHOULD pass WHEN the loss is within the policy', () {
      _expectPassesWithin(invariant, '<p>keep drop</p>', '<p>keep</p>', const FixturePolicy(maxMissingTextTokens: 1));
    });

    test('SHOULD compare plain text input word by word with HTML output split by <br>', () {
      expect(
        invariant.check(subject(
          'hello\nworld &',
          'hello<br>world &amp;',
          format: FixtureFormat.text,
        )),
        isNull,
      );
    });
  });

  group('LinksAndImagesPreservedInvariant', () {
    const invariant = LinksAndImagesPreservedInvariant();

    test('SHOULD pass WHEN links and images are kept', () {
      expect(invariant.check(subject('<a href="x">a</a><img src="i">', '<a href="y">a</a><img src="j">')), isNull);
    });

    test('SHOULD fail WHEN a link or an image is lost', () {
      final message = invariant.check(subject('<a href="x">a</a><img src="i">', '<a>a</a>'));

      expect(message, contains('1 link(s) lost'));
      expect(message, contains('1 image(s) lost'));
    });

    test('SHOULD pass WHEN the loss is within the policy', () {
      _expectPassesWithin(invariant, '<img src="i"><img src="j">', '<img src="i">', const FixturePolicy(maxLostImages: 1));
    });

    test('SHOULD skip plain text input', () {
      expect(invariant.check(subject('http://a.test', 'text', format: FixtureFormat.text)), isNull);
    });
  });

  group('SafeHtmlInvariant', () {
    const invariant = SafeHtmlInvariant();

    test('SHOULD pass on sanitized output', () {
      expect(invariant.check(subject('', '<a href="https://a.test" title="on">x</a><img src="data:image/png;base64,AA">')), isNull);
    });

    test('SHOULD fail on a script element', () {
      expect(invariant.check(subject('', '<script>alert(1)</script>')), contains('<script>'));
    });

    test('SHOULD fail on an event handler attribute', () {
      expect(invariant.check(subject('', '<img src="x" ONERROR="a()">')), contains('handler onerror'));
    });

    for (final url in ['javascript:a()', ' JavaScript:a()', 'java\tscript:a()', 'java\nscript:a()']) {
      test('SHOULD fail on the javascript URL ${Uri.encodeComponent(url)}', () {
        expect(invariant.check(subject('', '<a href="$url">x</a>')), contains('uses javascript:'));
      });
    }
  });
}
