import 'package:collection/collection.dart';
import 'package:golden_kit/src/corpus/fixture.dart';
import 'package:golden_kit/src/invariant/invariant.dart';
import 'package:golden_kit/src/suite/policy_book.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// One fixture passed through one HTML-producing pipeline.
class HtmlTransformSubject {
  HtmlTransformSubject({
    required this.fixture,
    required this.input,
    required this.output,
    required this.policy,
  });

  final Fixture fixture;
  final String input;
  final String output;
  final FixturePolicy policy;

  late final Document outputDocument = html_parser.parse(output);

  /// Null for plain-text fixtures, whose input is not HTML.
  late final Document? inputDocument =
      fixture.format == FixtureFormat.html ? html_parser.parse(input) : null;
}

final _whitespace = RegExp(r'\s+');

/// Text nodes that never render as body text.
const _nonTextElements = {'head', 'script', 'style', 'template', 'noscript', 'title'};

List<String> _tokens(String text) => text.split(_whitespace).where((t) => t.isNotEmpty).toList();

/// Elements that separate words when rendered; inline ones (`a`, `span`)
/// do not, so an autolinked `<user@x>` stays one word.
const _wordBreakingElements = {
  'address', 'article', 'blockquote', 'br', 'center', 'dd', 'div', 'dl', 'dt', 'footer', //
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hr', 'li', 'ol', 'p', 'pre', 'section', //
  'table', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr', 'ul',
};

/// Body words as rendered: text joined across inline tags, split at blocks.
List<String> _documentTokens(Document document) {
  final body = document.body;
  if (body == null) return const [];
  final text = StringBuffer();
  void visit(Node node) {
    if (node is Text) {
      text.write(node.data);
      return;
    }
    if (node is! Element) return node.nodes.forEach(visit);
    if (_nonTextElements.contains(node.localName)) return;
    final breaks = _wordBreakingElements.contains(node.localName);
    if (breaks) text.write(' ');
    node.nodes.forEach(visit);
    if (breaks) text.write(' ');
  }

  visit(body);
  return _tokens(text.toString());
}

/// Body text of the input survives the pipeline (hidden text counts too, so a
/// `display:none` preheader is not a false alarm).
class TextPreservedInvariant implements Invariant<HtmlTransformSubject> {
  const TextPreservedInvariant();

  @override
  String get id => 'text-preserved';

  @override
  String? check(HtmlTransformSubject subject) {
    final input = subject.inputDocument;
    final expected = input == null ? _tokens(subject.input) : _documentTokens(input);
    final remaining = _counts(_documentTokens(subject.outputDocument));
    final missing = <String>[];
    for (final token in expected) {
      final count = remaining[token] ?? 0;
      if (count == 0) {
        missing.add(token);
      } else {
        remaining[token] = count - 1;
      }
    }
    final allowed = subject.policy.maxMissingTextTokens;
    if (missing.length <= allowed) return null;
    return '${missing.length} text token(s) of ${expected.length} lost (allowed $allowed), '
        'first: ${missing.take(5).map((t) => '"${_clip(t)}"').join(', ')}';
  }

  static Map<String, int> _counts(List<String> tokens) =>
      tokens.fold(<String, int>{}, (counts, token) => counts..update(token, (n) => n + 1, ifAbsent: () => 1));

  static String _clip(String token) => token.length <= 30 ? token : '${token.substring(0, 30)}…';
}

/// Links and images are not dropped beyond what the suite's policy allows.
class LinksAndImagesPreservedInvariant implements Invariant<HtmlTransformSubject> {
  const LinksAndImagesPreservedInvariant();

  @override
  String get id => 'links-and-images-preserved';

  @override
  String? check(HtmlTransformSubject subject) {
    final input = subject.inputDocument;
    if (input == null) return null;
    final output = subject.outputDocument;
    final lostLinks = _count(input, 'a[href]') - _count(output, 'a[href]');
    final lostImages = _count(input, 'img') - _count(output, 'img');
    final problems = [
      if (lostLinks > subject.policy.maxLostLinks)
        '$lostLinks link(s) lost (allowed ${subject.policy.maxLostLinks})',
      if (lostImages > subject.policy.maxLostImages)
        '$lostImages image(s) lost (allowed ${subject.policy.maxLostImages})',
    ];
    return problems.isEmpty ? null : problems.join('; ');
  }

  static int _count(Document document, String selector) => document.querySelectorAll(selector).length;
}

/// Output of a sanitizing pipeline runs no script.
class SafeHtmlInvariant implements Invariant<HtmlTransformSubject> {
  const SafeHtmlInvariant();

  static const _urlAttributes = {'href', 'src', 'action', 'formaction', 'xlink:href'};

  @override
  String get id => 'safe-html';

  @override
  String? check(HtmlTransformSubject subject) {
    final document = subject.outputDocument;
    final problems = <String>[
      if (document.querySelectorAll('script').isNotEmpty) 'contains <script>',
    ];
    for (final element in document.querySelectorAll('*')) {
      for (final MapEntry(:key, :value) in element.attributes.entries) {
        final name = key.toString().toLowerCase();
        if (name.startsWith('on')) {
          problems.add('<${element.localName}> has handler $name');
        } else if (_urlAttributes.contains(name) && _isJavascriptUrl(value)) {
          problems.add('<${element.localName}> $name uses javascript:');
        }
      }
    }
    return problems.isEmpty ? null : problems.toSet().take(5).join('; ');
  }

  /// Browsers ignore ASCII whitespace and control characters inside a scheme.
  static bool _isJavascriptUrl(String value) {
    final scheme = String.fromCharCodes(
      value.codeUnits.whereNot((unit) => unit <= 0x20).take('javascript:'.length),
    );
    return scheme.toLowerCase() == 'javascript:';
  }
}
