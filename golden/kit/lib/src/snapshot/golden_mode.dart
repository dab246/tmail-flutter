import 'dart:io';

/// Whether golden tests verify stored snapshots or regenerate them.
///
/// One switch for every kind of golden: `GOLDEN_UPDATE=1` regenerates text
/// snapshots here, and `golden/run.sh --update` sets it for the pixel runner.
enum GoldenMode {
  verify,
  update;

  static const environmentVariable = 'GOLDEN_UPDATE';

  static GoldenMode fromEnvironment([Map<String, String>? environment]) =>
      (environment ?? Platform.environment)[environmentVariable] == '1' ? update : verify;
}
