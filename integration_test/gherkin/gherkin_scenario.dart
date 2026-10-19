import 'package:patrol/patrol.dart';

import '../base/base_test_scenario.dart';
import '../base/test_base.dart';
import '../factories/robot_factory_provider.dart';
import 'feature_world.dart';
import 'scenario_metadata.dart';

typedef ScenarioBody = Future<void> Function(PatrolIntegrationTester $);

/// Declares one Gherkin scenario as a Patrol test.
///
/// Generated code calls it once per scenario (see bdd_options.yaml). The tags
/// are validated first, so a malformed scenario fails the run instead of being
/// skipped by `--tags`. Setup and teardown run inside the test, once per
/// scenario, and teardown also runs when a step fails.
void gherkinPatrolTest(
  String title,
  ScenarioBody body, {
  List<String> tags = const [],
}) {
  final metadata = ScenarioMetadata.parse(tags);
  final testBase = TestBase();

  patrolTest(
    '${metadata.id} $title',
    config: TestBase.patrolTesterConfig,
    tags: metadata.selectableTags,
    platformAutomatorConfig: TestBase.platformAutomatorConfig,
    framePolicy: TestBase.framePolicy,
    ($) async {
      await testBase.setUpEnvironment();
      try {
        await testBase.setupTest();
        await _FeatureScenario($, createRobotFactory($), body).execute();
      } finally {
        FeatureWorld.close();
        await testBase.tearDownEnvironment();
      }
    },
  );
}

/// Runs the scenario through [BaseTestScenario], so login seeding stays in
/// one place.
class _FeatureScenario extends BaseTestScenario {
  final ScenarioBody _body;

  const _FeatureScenario(super.$, super.robots, this._body);

  @override
  Future<void> runTestLogic() {
    FeatureWorld.open(robots);
    return _body($);
  }
}
