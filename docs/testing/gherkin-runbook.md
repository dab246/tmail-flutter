# Gherkin non-regression scenarios: runbook

How to run, add and debug the scenarios in `integration_test/features/`. Rules for writing them: [gherkin-conventions.md](gherkin-conventions.md).

## How it fits together

1. `bdd_widget_test` (a `build_runner` builder, configured in `bdd_options.yaml`) turns every `.feature` into a Patrol test `<topic>_test.dart` next to it, and writes a stub for every step that has no definition yet.
2. Each scenario becomes one `gherkinPatrolTest(...)` call (`integration_test/gherkin/gherkin_scenario.dart`). It validates the tags, boots the app, seeds bob's login, runs the steps, and always resets the backend afterwards, pass or fail.
3. Patrol discovers the generated `*_test.dart` like any other e2e test, so `--target`, `--tags`, reports and CI work unchanged.

## Setup

```bash
fvm use
./scripts/prebuild.sh      # pub get + build_runner: (re)generates the feature tests
```

Re-run `dart run build_runner build --workspace` after changing a `.feature` file. A malformed feature file fails this build with the file, line and column.

## Run locally (web)

Needs Docker and Chrome. The script starts the James backend, the reset server, and runs Patrol.

```bash
# every scenario of one feature
PATROL_TAGS='web && gherkin' bash scripts/patrol-web-local-integration-test-with-docker.sh \
  --target integration_test/features/composer/composer_editor_shortcuts_test.dart

# by tag across all features (and classic tests when the tag matches them)
PATROL_TAGS='web && P1' bash scripts/patrol-web-local-integration-test-with-docker.sh
PATROL_TAGS='web && NR-COMPOSER-001' bash scripts/patrol-web-local-integration-test-with-docker.sh
```

`PATROL_TAGS` defaults to `web`, i.e. what CI runs. It is a `package:test` boolean selector (`&&`, `||`, `!`, parentheses) over the scenario tags plus `gherkin`. The script rewrites the tracked `env.file` and `backend-docker/jmap.properties`; restore them with `git checkout -- env.file backend-docker/jmap.properties` before committing.

## CI

- **Every PR**: `Web integration tests` runs every `@web` test, so every `@web` scenario too. A failing scenario fails the job.
- **Every PR**: `Analyze and test` runs `test/integration_test/gherkin/`. It fails on an invalid tag, a duplicate id, tags on `Feature:`, a feature outside `features/<area>/`, or a step stub that is still unimplemented.
- **Nightly**: `Integration tests` (Android, Firebase Test Lab) runs `@android` scenarios.

## Add a scenario

1. Pick the feature file of the area (or create `integration_test/features/<area>/<topic>.feature`).
2. Take the next free id for the area: `grep -rho '@NR-COMPOSER-[0-9]*' integration_test/features | sort | tail -1`.
3. Write the scenario and tags (see conventions). Add `@src:` only for a PR/issue you checked; add `@verified:` only after checking the expected outcome against the product.
4. `dart run build_runner build --workspace`. New steps appear as stubs in `integration_test/features/steps/`.
5. Implement each stub with robot calls (next section), run the scenario locally, then `fvm flutter test test/integration_test/gherkin/`.
6. Commit the `.feature` file and the step files, not the generated `*_test.dart`.

## Add a step definition

The generator names the file and function after the step text and passes `{…}` values as parameters:

```dart
// integration_test/features/steps/bob_has_opened_a_new_composer.dart
import '../../gherkin/gherkin_support.dart';

/// Usage: bob has opened a new composer
Future<void> bobHasOpenedANewComposer(PatrolIntegrationTester $) async {
  final robots = FeatureWorld.current.robots;
  await robots.commonRobot().waitForMailboxReady();
  ...
}
```

Keep steps to robot calls. When a robot method is missing, add it to the robot (`integration_test/robots/abstract/` + mobile + `web/` implementations), not to the step. Keep the generated `/// Usage:` line.

## Read a failure

| What you see | Meaning |
|---|---|
| `UnimplementedError` from `integration_test/features/steps/<x>.dart` | Step `<x>` is undefined: implement the stub. |
| `Playwright stderr: DartError: FormatException: Invalid scenario tags: …`, `Total: 0`, exit 1 | A scenario breaks the tag rules; the message lists every problem. It stops the whole test bundle from loading, so no test of that run executes. The unit-test guard reports the same thing on the PR, with the scenario name. |
| `WaitUntilVisibleTimeoutException` (or another assertion) under `❌ … NR-<AREA>-<NNN> <title>` | The behaviour regressed, or the step/robot is wrong. The message names the finder that failed (e.g. `with text "Apply"`) and the Patrol log above it lists the last actions; timeouts carry no Dart stack, so map the finder back to the `Then` step. |
| `Test summary: Total: 0`, `Playwright process exited unexpectedly with code 1` | Nothing matched `--tags`/`--target` (Playwright fails an empty run), a tag is invalid (row above), or the page failed to load before tests started (`Failed to fetch` in Playwright stderr: re-run, and do not run `flutter pub get` meanwhile). |
| `Backend reset failed` warning in the log | The reset after the previous test failed, so the backend may hold leftover data. Same behaviour as all other e2e tests today. |

Reports: Playwright HTML report in `playwright-report/`, traces and videos in `test-results/`. Add `--web-reporter='["list","junit"]'` for `playwright-report/results.xml`.

## Limitations

- Only web has been run end to end. `@android`/`@ios` scenarios rely on the same Patrol path but have not been run yet.
- No cucumber-style "ambiguous step": a step is bound by its normalised text, so two texts that normalise the same way share one function, and a different wording makes a new stub.
- `@src` and `@verified` cannot be selected with `--tags`; grep the feature files instead.
- A failed backend reset only logs a warning, for scenarios and classic tests alike.
- `bdd_widget_test` is pinned to 3.0.3: 3.0.4 generates `package:material_ui` imports, which need Flutter 3.47+.
