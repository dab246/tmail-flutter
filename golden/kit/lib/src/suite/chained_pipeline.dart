import 'package:golden_kit/src/corpus/fixture.dart';
import 'package:golden_kit/src/invariant/html_invariants.dart';
import 'package:golden_kit/src/invariant/invariant.dart';
import 'package:golden_kit/src/suite/mutation_suite.dart';
import 'package:golden_kit/src/suite/text_golden_suite.dart';

/// A feature that transforms content another feature already transformed,
/// e.g. print takes what the email view loaded. Invariants compare the raw
/// fixture with the final output; mutants come from the [last] stage only,
/// since the [first] stage is mutated by its own suite.
class ChainedPipeline implements MutablePipeline {
  const ChainedPipeline({
    required this.id,
    required this.first,
    required this.last,
    required this.invariants,
  });

  @override
  final String id;
  final TextPipeline first;
  final TextPipeline last;

  @override
  final List<Invariant<HtmlTransformSubject>> invariants;

  @override
  bool accepts(Fixture fixture) => first.accepts(fixture);

  @override
  Future<String> run(Fixture fixture, String content) async =>
      last.run(fixture, await first.run(fixture, content));

  @override
  Iterable<PipelineMutant> get mutants {
    final stage = last;
    if (stage is! MutablePipeline) return const [];
    return [
      for (final mutant in stage.mutants)
        PipelineMutant(
          id: mutant.id,
          pipeline: ChainedPipeline(id: id, first: first, last: mutant.pipeline, invariants: invariants),
        ),
    ];
  }
}
