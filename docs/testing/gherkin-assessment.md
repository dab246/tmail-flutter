# Gherkin non-regression testing: assessment and implementation plan

Phase 1 deliverable, written before the MVP. The MVP follows it with the names `gherkinPatrolTest` (here `nrPatrolTest`) and `integration_test/gherkin/` (here `integration_test/base/nr_patrol_test.dart`); steps live in `integration_test/features/steps/` so feature tests and steps share one import path. Decisions taken for the MVP are in §9.

Legend: **[F]** verified fact (with evidence), **[I]** inference not yet executed, **[R]** recommendation.

## 1. Current state

### 1.1 Test layers

| Layer | Location | Runner | CI |
|---|---|---|---|
| Unit / widget | `test/`, `<package>/test/` | `flutter test` via `scripts/test.sh` | `analyze-test.yaml` on every PR, after `scripts/prebuild.sh` |
| E2E (web) | `integration_test/tests/**` | Patrol 4.5.0 + patrol_cli 4.3.1, Playwright under the hood | `patrol-web-integration-test.yaml` on every PR → `reusable-web-integration-test.yaml` → `scripts/patrol-web-integration-test-with-docker.sh`; also `Jenkinsfile` and the release gate in `image-sentry.yaml` |
| E2E (Android) | same files | `patrol build android` + Firebase Test Lab | `patrol-integration-test.yaml`, nightly / manual, needs GCP secrets |

### 1.2 E2E building blocks to reuse [F]

- **Entry point** — every test file calls `TestBase().runPatrolTest(description, scenarioBuilder, tags)` (`integration_test/base/test_base.dart:20`). It boots the real app (`runTmail()`), registers `patrolSetUp`/`patrolTearDown` (`:25`, `:27`) and resets the backend in teardown.
- **Login** — `BaseTestScenario.execute()` seeds basic-auth credentials from `--dart-define`s into app storage so the app skips login (`integration_test/base/base_test_scenario.dart:20-42`). The signed-in user is `bob@example.com`; `alice@example.com` is available as `ADDITIONAL_MAIL_RECIPIENT`.
- **Platform adapters already exist** — `RobotFactory` (`integration_test/factories/robot_factory.dart`) with `WebRobotFactory` / `MobileRobotFactory`, selected by a conditional export (`robot_factory_provider.dart`). This is exactly the plan's "web adapter / mobile adapter" layer; no new adapter is needed.
- **Data setup** — `ScenarioUtilsMixin` provisions emails, identities, folders and labels through the app's own interactors over JMAP (`integration_test/mixin/scenario_utils_mixin.dart:256` for identities).
- **Isolation** — `BackendResetClient.reset()` calls `scripts/backend-reset-server.py`, which wipes all test users' data via James WebAdmin and restores bob's mailbox from `provisioning/integration_test/backup.zip`.
- **Tags** — only `android | ios | web` (`integration_test/models/test_tags.dart`); default is `[ios]` (`test_base.dart:23`). Web CI runs `--tags=web` (`scripts/patrol-web-integration-test-with-docker.sh:62`), Android CI `--tags=android` (`scripts/patrol-integration-test-with-docker.sh:126`). 34 of 118 E2E files are tagged `web`.
- **Discovery** — patrol_cli bundles every `integration_test/**/*_test.dart` into a generated, gitignored `test_bundle.dart` (`pubspec.yaml:489`, `.gitignore:123`). Each file becomes a `group(...)`.
- **Tag filtering** — Patrol evaluates `--tags` / `--exclude-tags` as a `BooleanSelector` over each test's `metadata.tags` inside the app (`patrol-4.5.0/lib/src/common.dart:254-268`), so `--tags='web && P1'` works.
- **Web execution model** — Playwright reloads the page per test (`patrol-4.5.0/web_runner/tests/test.spec.ts`), with 1 worker and no retries by default (`playwright.config.ts:7,14`). Reporters: `html | json | junit | list | dot | line | github` via `--web-reporter`; output dirs via `--web-results-dir` / `--web-report-dir`; video via `--web-video`.
- **Generated code policy** — `*.g.dart`, `*.mocks.dart` and `test_bundle.dart` are gitignored and rebuilt by `prebuild.sh` (`dart run build_runner build --workspace`). CI runs prebuild before analyze, unit tests and E2E.

### 1.3 Gaps the framework must handle

- **One test per file today.** No E2E file calls `runPatrolTest` twice. `runPatrolTest` registers setUp/tearDown hooks *per call*, so several scenarios in one group would run the backend reset N times per test. A Gherkin feature holds several scenarios, so it cannot reuse `runPatrolTest` as is.
- **Reset failures are swallowed** — `BackendResetClient.reset()` only logs a warning (`integration_test/utils/backend_reset_client.dart:39`), so a failed reset can leak state into the next scenario.
- **Example in the brief is not verified.** `@src:pr-4947` is real (merged 2026-10-15) but it changed the *identity creator's* default address and made the identity sort stable. The composer selects `listFromIdentities.first`, i.e. the lowest `sortOrder` (`lib/features/composer/presentation/extensions/setup_selected_identity_extension.dart:31`); "the user's own identity is selected by default" only holds if that identity has the lowest `sortOrder`, and no test asserts it with custom identities. It must not be marked `@verified` until checked (see §9).

## 2. Options considered

| Option | Verdict | Evidence |
|---|---|---|
| `flutter_gherkin` 2.0.0 | **Rejected** | SDK `<3.0.0`, built on `flutter_driver`; last release 2021 |
| `gherkin` 3.1.0 | **Rejected** | SDK `<3.0.0`; last release 2022 |
| `bdd_widget_test` 3.0.3 (build_runner codegen) | **Recommended** | SDK `^3.8.0`; uses the official `cucumber_gherkin` 42 parser; strict (malformed files fail the build); `testMethodName` / `testerType` / `testerName` options make it emit Patrol tests; resolves cleanly against the workspace (dry run adds only `bdd_widget_test`, `cucumber_gherkin`, `cucumber_messages`, `diacritic`) |
| `bdd_widget_test` 2.1.4 | Rejected | Hand-written scanner silently drops malformed lines, and several tags on one line become a single tag (fixed in 3.0.0 per its changelog) — both break our tag convention |
| `bdd_widget_test` 3.0.4 | Rejected for now | Generated code imports `package:material_ui`, which targets Flutter 3.47; the repo is on 3.38.9 |
| Custom generator on `cucumber_gherkin` | Fallback | Full control (regex steps, real ambiguity detection) but a parser-to-Dart generator to own; only worth it if the MVP hits a blocker in `bdd_widget_test` |
| Parse `.feature` at runtime in the app | Rejected | Needs bundling feature files as assets on every platform and a runtime step registry; codegen gives compile-time step binding for free |

### 2.1 Spike result [F]

A throwaway package in the scratchpad (not in the repo) ran `bdd_widget_test` 3.0.3 with `testMethodName: nrPatrolTest`, `testerType: PatrolIntegrationTester`, `testerName: $`. Observed:

- `composer_identity.feature` → `composer_identity_test.dart`, so patrol_cli discovers it with no config change.
- Each scenario → `nrPatrolTest('''title''', ($) async { ...steps }, tags: [...])`; `Background` → a `bddSetUp($)` call at the top of each test; `Scenario Outline` → one test per `Examples` row.
- Each step → a Dart function in its own file (`bob_picks_identity.dart`), parameters written as `{'value'}` become typed arguments.
- **A missing step is generated as a stub that `throw UnimplementedError()`** — it fails, never passes silently.
- **Scenario tags are passed verbatim**, including `src:pr-4947` and `verified:2026-10-16`. `test_api` rejects any tag not matching `^[a-zA-Z_-][a-zA-Z0-9_-]*$` (`test_api-0.7.7/lib/src/backend/util/identifier_regex.dart:9`), so those two would throw at declaration. The wrapper must strip `key:value` metadata before calling `patrolTest` (§5).
- **Feature-level tags become a library `@Tags([...])` annotation**, not test tags. [I] Patrol imports test files into `test_bundle.dart`, where annotations on imported libraries are not applied, so feature-level tags would silently never match `--tags`. → Convention: tags on scenarios (or `Rule`) only.

### 2.2 Known limits of `bdd_widget_test`

- **No "ambiguous step" concept.** A step binds by its normalised text (letters/digits → file and function name), not by regex. Two texts that normalise to the same name share one function; different wording creates a new stub. The cucumber "ambiguous" failure cannot happen, and "undefined" is the generated stub.
- Parameters must use `{...}`, not `"..."`; quoted text becomes part of the step name.
- 3.0.3 was published 2026-10-14 (3.x line since 2026-10-07). Pin the exact version.

## 3. Recommended architecture

```
integration_test/features/**/*.feature        specification (committed)
        │  build_runner (prebuild.sh)  ── bdd_widget_test featureBuilder
        ▼
integration_test/features/**/*_test.dart      generated Patrol tests (gitignored)
        │  calls
        ▼
nrPatrolTest(title, body, tags)               wrapper: metadata validation + lifecycle
        │  reuses TestBase.setupTest, BaseTestScenario login seeding, BackendResetClient
        ▼
integration_test/steps/*.dart                 step definitions → existing robots via RobotFactory
        ▼
patrol test (web: Playwright | Android: orchestrator)  →  exit code + html/json/junit report
```

Responsibilities:

| Concern | Owner | New code? |
|---|---|---|
| Discovery and parsing | `bdd_widget_test` + `cucumber_gherkin` at build time | config only |
| Test discovery at run time | patrol_cli (`*_test.dart`) | none |
| Tag filtering | Patrol `--tags` / `--exclude-tags` | none |
| Metadata rules (ID, priority, platform, `src`, `verified`) | `nrPatrolTest` at run time + a unit test on every PR | small |
| Lifecycle, login, reset, teardown after failure | `nrPatrolTest` reusing `TestBase` / `BaseTestScenario` | small |
| UI automation per platform | existing robots | none |
| Steps | `integration_test/steps/` | per scenario |
| Report and evidence | Patrol / Playwright reporters | flags only |

No generic plugin system, no new adapter layer, no custom parser.

## 4. Proposed repository layout

```
bdd_options.yaml                                  generator options (root package)
docs/testing/
  gherkin-assessment.md                           this file
  gherkin-conventions.md                          Phase 2
  gherkin-runbook.md                              Phase 5
integration_test/
  features/
    composer/
      composer_editor_shortcuts.feature
      composer_editor_shortcuts_test.dart         generated, gitignored
  steps/                                          one function per file (bdd_widget_test convention)
    bob_has_opened_a_new_composer.dart
    ...
  base/
    nr_patrol_test.dart                           wrapper + metadata + world
test/
  integration_test_features/
    feature_metadata_test.dart                    PR-time guard, no backend
```

`.gitignore` gains `integration_test/features/**/*_test.dart`. Hand-written files in `features/` must not end in `_test.dart`.

## 5. Wrapper and step design (sketches)

### 5.1 `nrPatrolTest`

Signature matches what the generator emits. Lifecycle runs inside the test body with `try/finally`, so teardown runs exactly once per scenario, also after a failure, and hooks are not stacked when a feature has several scenarios.

```dart
typedef ScenarioBody = Future<void> Function(PatrolIntegrationTester $);

void nrPatrolTest(
  String title,
  ScenarioBody body, {
  List<String> tags = const [],
}) {
  // Throws at declaration on a bad tag set, so a malformed scenario never runs.
  final metadata = ScenarioMetadata.parse(title, tags);

  patrolTest(
    '${metadata.id} $title',            // ID visible in every report
    config: TestBase.patrolTesterConfig, // extracted from TestBase, not duplicated
    tags: metadata.selectableTags,       // ID, priority, platforms, optional groups; no key:value
    ($) async {
      PlatformInfo.isIntegrationTesting = true;
      try {
        await TestBase().setupTest();
        await FeatureScenario($, createRobotFactory($), body).execute();
      } finally {
        FeatureWorld.clear();
        PlatformInfo.isIntegrationTesting = false;
        await BackendResetClient.reset();
      }
    },
  );
}

/// Reuses BaseTestScenario so login seeding stays in one place.
class FeatureScenario extends BaseTestScenario {
  const FeatureScenario(super.$, super.robots, this._body);
  final ScenarioBody _body;

  @override
  Future<void> runTestLogic() {
    FeatureWorld.start($, robots);
    return _body($);
  }
}
```

Required changes to existing test infrastructure (test code only, behaviour-preserving): extract `TestBase`'s inline `PatrolTesterConfig` into a shared constant. Whether `BackendResetClient.reset()` should fail the scenario instead of logging is a separate decision (§9).

### 5.2 Scenario world

Steps only receive `$`. Per-scenario state (robots, provisioned data) lives in a `FeatureWorld` that the wrapper creates before the body and clears in `finally`, so nothing leaks between scenarios.

```dart
class FeatureWorld {
  FeatureWorld._(this.robots);
  final RobotFactory robots;
  final Map<String, Object> _values = {};

  static FeatureWorld? _current;
  static FeatureWorld get current =>
      _current ?? (throw StateError('Step called outside nrPatrolTest'));

  static void start(PatrolIntegrationTester $, RobotFactory robots) =>
      _current = FeatureWorld._(robots);
  static void clear() => _current = null;

  void put<T extends Object>(String key, T value) => _values[key] = value;
  T get<T extends Object>(String key) => _values[key] as T? ??
      (throw StateError('No "$key" in this scenario; a Given step is missing'));
}
```

### 5.3 Steps

Thin glue over robots; setup steps never assert business outcomes, `Then` steps always assert.

```dart
// integration_test/steps/bob_has_opened_a_new_composer.dart
Future<void> bobHasOpenedANewComposer(PatrolIntegrationTester $) async {
  final robots = FeatureWorld.current.robots;
  await robots.commonRobot().waitForMailboxReady();
  await robots.threadRobot().openComposer();
  await robots.composerRobot().expectComposerViewVisible();
  await robots.composerRobot().grantContactPermission();
}

// integration_test/steps/the_custom_insert_link_dialog_is_shown.dart
Future<void> theCustomInsertLinkDialogIsShown(PatrolIntegrationTester $) =>
    FeatureWorld.current.robots
        .composerRobot()
        .expectInsertLinkDialogVisible(AppLocalizations());
```

### 5.4 PR-time guard

`test/integration_test_features/feature_metadata_test.dart` runs in the existing unit-test CI (no backend, seconds). It reads every `.feature` and fails on: duplicate or missing `@NR-<AREA>-<NNN>`, missing priority or platform tag, unknown tag key, bad `@src`/`@verified` format, tags on `Feature:`, and any step file still containing `UnimplementedError`. It uses `cucumber_gherkin` (already resolved) rather than a hand parser, and anchored regexes only (ReDoS-checked when implemented).

## 6. Sample feature (grounded, not yet executable)

Source: issue #4488, fixed by PR #4539 (merged 2026-05-22), covered today by `integration_test/tests/composer/open_insert_link_dialog_via_keyboard_shortcut_test.dart` (web). The robot asserts the Flutter "Apply" button, which only the custom overlay renders (`integration_test/robots/web/web_composer_robot.dart:84-90`).

```gherkin
Feature: Composer editor keyboard shortcuts
  The rich-text editor maps shortcuts to Twake Mail's own dialogs
  instead of the embedded editor's native ones.

  @NR-COMPOSER-001 @P2 @web @src:pr-4539
  Scenario: the insert-link shortcut opens the custom link dialog
    Given bob has opened a new composer
    When bob presses the insert-link shortcut in the editor
    Then the custom insert-link dialog is shown
```

`@verified` is deliberately absent: it is added only after this scenario has run green through the new runner (MVP acceptance).

## 7. Execution strategy

### Local (web)

```bash
./scripts/prebuild.sh                                  # generates *_test.dart from .feature
bash scripts/patrol-web-local-integration-test-with-docker.sh   # existing script; runs --tags=web
# Narrow it: same script with --target integration_test/features and --tags='web && P1'
```

The runbook (Phase 5) will add a `--target`/`--tags` pass-through to the local script rather than a new script. Known side effects of the existing local scripts (they rewrite `backend-docker/jmap.properties` and `env.file`) will be documented.

### CI

- **No new workflow for the MVP.** Web scenarios carry `@web`, so the existing PR job (`--tags=web`, all `integration_test/**`) already runs them and fails the job on a regression. Existing tests are unaffected.
- The metadata guard runs inside `analyze-test.yaml` with the other unit tests.
- Evidence: add `--web-reporter='["list","junit","html"]'` and upload `playwright-report/` + `test-results/` as an artifact on failure. Needs a small change to the reusable workflow (Phase 5, opt-in).
- Android: scenarios tagged `@android` would be picked up by the nightly FTL job, but that is not verified in the MVP.

## 8. MVP breakdown

| # | Task | Depends on | Done when |
|---|---|---|---|
| 1 | Conventions doc + tag semantics (Phase 2) | review of this doc | `gherkin-conventions.md` merged-ready |
| 2 | Add `bdd_widget_test: 3.0.3` (dev), `bdd_options.yaml`, `.gitignore` rule | 1 | `prebuild.sh` generates the sample test; `flutter analyze` clean |
| 3 | `nrPatrolTest`, `ScenarioMetadata`, `FeatureWorld`; extract `TestBase` config | 2 | unit tests for `ScenarioMetadata` cover valid / missing ID / duplicate platform / bad `src` / bad date / unknown key |
| 4 | Steps + `composer_editor_shortcuts.feature` | 3 | scenario passes on web locally |
| 5 | Negative controls (local, not committed): failing `Then`, undefined step, tag filter selecting 0 / 1 / all, teardown after failure | 4 | each outcome and exit code recorded in the PR |
| 6 | Metadata guard unit test | 3 | fails on each rule, passes on the repo |
| 7 | Runbook; optional CI reporter/artifact flags | 4 | documented commands reproduced |

### Acceptance criteria (from the brief, mapped)

1. Feature discovered and executed → task 4. 2. Pass reported → 4. 3. Failing assertion → failed + non-zero exit → 5. 4. Undefined step reported → 5 (stub throws `UnimplementedError`) and 6. 5. Tag filtering → 5. 6. Teardown after failure → 5 (backend reset observed in reset-server log). 7. Real Composer behaviour → 4. 8. Existing tests still pass → existing web CI job. 9. Local command works → 7. 10. CI fails on genuine regression → existing job + 5.

### Risks

| Risk | Mitigation |
|---|---|
| `bdd_widget_test` 3.x is days old | Pin 3.0.3; generated output is plain Dart we can read; fallback = custom generator on `cucumber_gherkin` |
| Empty `--tags` selection might pass | [I] Playwright normally fails on "no tests found", but the Patrol spec only logs `PATROL_TESTS env is empty`; verify in task 5; if it passes, the runbook command guards it |
| Silent backend-reset failure leaks state | Decide in §9; at minimum surface it in the scenario log |
| Step-name collisions from normalisation | Guard test lists step files used by more than one distinct step text |
| Generated tests missing when someone skips prebuild | Same as `*.g.dart` today; CI always runs prebuild |

## 9. Non-goals and open questions

**Non-goals (MVP):** migrating the 118 existing E2E tests; mobile execution evidence; a custom parser or report dashboard; retries (`--web-retries` stays 0 so flakiness is visible); running features outside Patrol.

**Questions the repository cannot answer** (MVP default in bold, to confirm):

1. Is a dev dependency released this month (`bdd_widget_test` 3.0.3, 2026-10-14) acceptable under the team's dependency policy? **Pinned to 3.0.3.**
2. Should NR scenarios run in the PR web job (adds ~1 app boot per scenario) or only nightly / on a `@smoke` subset? **PR web job, like every `@web` test.**
3. Should a failed backend reset fail the scenario? Today it is a warning for all E2E tests; changing it affects them all. **Unchanged; documented as a limitation.**
4. Who may set `@verified`, and is a date enough or should it name the build/commit? **Date only; set after checking the outcome against the product.**
5. For the brief's identity example: what `sortOrder` does James give bob's server-created identity versus identities created from the app? This decides whether "own identity by default" is real behaviour before it becomes a scenario. **Not used; the MVP scenario is the insert-link shortcut.**

## 10. Recommendation

Implement `bdd_widget_test` 3.0.3 codegen feeding a thin `nrPatrolTest` wrapper that reuses `TestBase`, `BaseTestScenario` and the existing robots, starting with the single web scenario in §6. It reuses the whole existing E2E stack (discovery, login, reset, robots, tag filtering, CI job) and adds only a generator config, one wrapper file, a metadata guard and step glue.

The MVP must prove: (a) a `.feature` scenario runs through the real Patrol web job and passes; (b) a failing `Then` and an undefined step both fail with a non-zero exit; (c) `--tags` selects exactly the intended scenarios and an empty selection does not pass silently; (d) the backend reset runs after a failing scenario; (e) `key:value` metadata never reaches `test_api` as a tag.
