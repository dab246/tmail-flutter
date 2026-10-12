# Golden tests

Regression tests for everything that turns email HTML into what users see. Design and rationale: [docs/dev/plan/golden-testing](../docs/dev/plan/golden-testing/README.md).

## Run

```bash
bash golden/run.sh                          # verify text + pixel goldens of every suite
bash golden/run.sh --suite email_view_html  # one suite
bash golden/run.sh --text                   # text goldens only (no Docker)
bash golden/run.sh --update                 # regenerate, then review the diff before committing
bash golden/run.sh --mutation               # prove the pixel goldens notice each removed viewer script/style
```

Text goldens alone, inside a suite: `flutter test` (verify) or `GOLDEN_UPDATE=1 flutter test` (update). Pixel goldens need Docker; they render in the pinned image of `playwright/Dockerfile` as linux/amd64, so local and CI pixels are identical.

## Layout

| Folder | Package | Role |
|---|---|---|
| `kit/` | `golden_kit` | Generic building blocks: corpus, snapshots, invariants, mutants, render export. No production dependency. |
| `adapters/tmail_html/` | `golden_tmail_html` | The app's HTML pipelines (`TmailPipelines`), run offline. |
| `corpus/` | data | Scrubbed or fabricated fixtures with a `manifest.json` each. |
| `suites/<suite>/` | `golden_<suite>` | One product surface: `suite.json`, `policies.json`, tests, goldens, optional Playwright plugin. |
| `playwright/` | npm | Generic pixel runner, Dockerfile, font profiles. |
| `tool/` | scripts | CI helpers. |

## When a golden fails

1. Read the failure: text goldens print the pipeline, fixture, line/column and both versions; pixel failures attach expected/actual/diff images and metrics to the Playwright report.
2. Unintended → fix the code. Intended → regenerate with `--update` and commit the goldens in a separate commit; the reviewer checks every changed file.
3. A `changes no fixture` failure means a transformer or viewer block has no fixture exercising it: add one to `corpus/`, or explain the survivor in the suite's test with a reason.
