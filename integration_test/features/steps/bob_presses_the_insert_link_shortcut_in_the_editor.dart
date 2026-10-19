import '../../gherkin/gherkin_support.dart';

/// Usage: bob presses the insert link shortcut in the editor
Future<void> bobPressesTheInsertLinkShortcutInTheEditor(
  PatrolIntegrationTester $,
) =>
    FeatureWorld.current.robots
        .composerRobot()
        .openInsertLinkDialogViaKeyboardShortcut();
