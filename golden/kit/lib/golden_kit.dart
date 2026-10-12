/// Building blocks shared by every golden suite.
///
/// Depends on no production package: suites and adapters depend on the kit,
/// never the other way round.
library;

export 'src/corpus/fixture.dart';
export 'src/corpus/fixture_corpus.dart';
export 'src/export/document_mutation.dart';
export 'src/export/render_export.dart';
export 'src/invariant/html_invariants.dart';
export 'src/invariant/invariant.dart';
export 'src/snapshot/golden_mode.dart';
export 'src/snapshot/gzip_file_snapshot_store.dart';
export 'src/snapshot/snapshot_store.dart';
export 'src/snapshot/text_snapshot.dart';
export 'src/suite/chained_pipeline.dart';
export 'src/suite/golden_layout.dart';
export 'src/suite/mutation_suite.dart';
export 'src/suite/package_root.dart';
export 'src/suite/policy_book.dart';
export 'src/suite/text_golden_suite.dart';
