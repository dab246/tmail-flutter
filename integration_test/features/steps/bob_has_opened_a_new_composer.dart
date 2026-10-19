import '../../gherkin/gherkin_support.dart';

/// Usage: bob has opened a new composer
Future<void> bobHasOpenedANewComposer(PatrolIntegrationTester $) async {
  final robots = FeatureWorld.current.robots;
  final composerRobot = robots.composerRobot();

  await robots.commonRobot().waitForMailboxReady();
  await robots.threadRobot().openComposer();
  await composerRobot.expectComposerViewVisible();
  await composerRobot.grantContactPermission();
}
