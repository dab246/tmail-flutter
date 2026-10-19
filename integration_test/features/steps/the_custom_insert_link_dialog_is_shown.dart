import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

import '../../gherkin/gherkin_support.dart';

/// Usage: the custom insert link dialog is shown
Future<void> theCustomInsertLinkDialogIsShown(PatrolIntegrationTester $) =>
    FeatureWorld.current.robots
        .composerRobot()
        .expectInsertLinkDialogVisible(AppLocalizations());
