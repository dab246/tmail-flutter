import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_kit/golden_kit.dart';

typedef _Step = String Function(String content);

class _Stage implements MutablePipeline {
  _Stage(this.id, this.steps);

  @override
  final String id;
  final Map<String, _Step> steps;

  @override
  List<Invariant<HtmlTransformSubject>> get invariants => const [];

  @override
  bool accepts(Fixture fixture) => fixture.format == FixtureFormat.html;

  @override
  Future<String> run(Fixture fixture, String content) async =>
      steps.values.fold<String>(content, (text, step) => step(text));

  @override
  Iterable<PipelineMutant> get mutants => [
        for (final name in steps.keys)
          PipelineMutant(id: 'without $name', pipeline: _Stage(id, {...steps}..remove(name))),
      ];
}

final _fixture = Fixture(name: 'eml_1', format: FixtureFormat.html, tags: const {}, file: File('unused'));

ChainedPipeline _chain({TextPipeline? last}) => ChainedPipeline(
      id: 'print',
      first: _Stage('preview', {'wrap': (t) => '[$t]'}),
      last: last ?? _Stage('print', {'upper': (t) => t.toUpperCase(), 'bang': (t) => '$t!'}),
      invariants: const [],
    );

void main() {
  test('SHOULD feed the first stage output to the last stage', () async {
    expect(await _chain().run(_fixture, 'a'), '[A]!');
  });

  test('SHOULD accept what the first stage accepts', () {
    expect(_chain().accepts(_fixture), isTrue);
    expect(
      _chain().accepts(Fixture(name: 't', format: FixtureFormat.text, tags: const {}, file: File('unused'))),
      isFalse,
    );
  });

  test('SHOULD mutate only the last stage, keeping the first one', () async {
    final mutants = _chain().mutants.toList();

    expect(mutants.map((m) => m.id), ['without upper', 'without bang']);
    expect(await mutants.first.pipeline.run(_fixture, 'a'), '[a]!');
    expect(mutants.first.pipeline.id, 'print');
  });

  test('SHOULD have no mutants WHEN the last stage cannot be mutated', () {
    final fixed = _chain(last: _chain());
    expect(fixed.mutants, hasLength(2));
    expect(ChainedPipeline(id: 'x', first: _chain(), last: _NotMutable(), invariants: const []).mutants, isEmpty);
  });
}

class _NotMutable implements TextPipeline {
  @override
  String get id => 'fixed';

  @override
  List<Invariant<HtmlTransformSubject>> get invariants => const [];

  @override
  bool accepts(Fixture fixture) => true;

  @override
  Future<String> run(Fixture fixture, String content) async => content;
}
