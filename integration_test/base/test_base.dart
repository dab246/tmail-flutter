import 'package:core/utils/config/env_loader.dart';
import 'package:core/utils/platform_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tmail_ui_user/main/main_entry.dart';

import '../models/test_tags.dart';
import '../utils/backend_reset_client.dart';
import 'base_scenario.dart';
import '../factories/robot_factory.dart';
import '../factories/robot_factory_provider.dart';

class TestBase {
  static final TestBase _instance = TestBase._internal();
  factory TestBase() => _instance;

  TestBase._internal();

  static const patrolTesterConfig = PatrolTesterConfig(
    settlePolicy: SettlePolicy.trySettle,
    existsTimeout: Duration(seconds: 30),
    visibleTimeout: Duration(seconds: 30),
    settleTimeout: Duration(seconds: 30),
    printLogs: true,
  );

  static final platformAutomatorConfig = PlatformAutomatorConfig.fromOptions(
    findTimeout: const Duration(seconds: 30),
  );

  static const framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  void runPatrolTest({
    required String description,
    required BaseScenario Function(PatrolIntegrationTester $, RobotFactory robots) scenarioBuilder,
    List<TestTags> tags = const [TestTags.ios],
  }) {
    patrolSetUp(setUpEnvironment);

    patrolTearDown(tearDownEnvironment);

    patrolTest(
      description,
      config: patrolTesterConfig,
      tags: tags.map((t) => t.name).toList(),
      platformAutomatorConfig: platformAutomatorConfig,
      framePolicy: framePolicy,
      ($) async {
        await setupTest();
        await scenarioBuilder($, createRobotFactory($)).execute();
      },
    );
  }

  Future<void> setupTest() async {
    await EnvLoader.loadEnvFile();
    await runTmail();

    final originalOnError = FlutterError.onError!;
    FlutterError.onError = (FlutterErrorDetails details) {
      originalOnError(details);
    };
  }

  Future<void> setUpEnvironment() async {
    PlatformInfo.isIntegrationTesting = true;
  }

  Future<void> tearDownEnvironment() async {
    PlatformInfo.isIntegrationTesting = false;
    await BackendResetClient.reset();
  }
}