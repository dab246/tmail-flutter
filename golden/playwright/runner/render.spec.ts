import { test } from '@playwright/test';

import { expectMatchesGoldens } from './capture';
import { collectMetrics, genericInvariants, invariantFailures } from './invariants';
import { openCase } from './session';
import { loadExport, loadPlugins, tagOf } from './suites';
import type { RenderCase, SuiteExport, SuitePlugin } from './types';

/** One test per exported case: invariants, then every tile against its golden. */
for (const plugin of loadPlugins()) {
  const suiteExport = loadExport(plugin);
  for (const renderCase of suiteExport.cases) {
    test(renderCase.id, { tag: tagOf(plugin.id, renderCase.target) }, ({ page }) =>
      renderAndCompare(page, plugin, suiteExport, renderCase),
    );
  }
}

async function renderAndCompare(
  page: Parameters<typeof openCase>[0],
  plugin: SuitePlugin,
  suiteExport: SuiteExport,
  renderCase: RenderCase,
): Promise<void> {
  const session = await openCase(page, { plugin, suiteExport, renderCase, documentPath: renderCase.document });
  const invariants = [...genericInvariants, ...plugin.invariants];
  await test.info().attach('metrics', {
    body: JSON.stringify(await collectMetrics(session), null, 2),
    contentType: 'application/json',
  });
  assertNone(await invariantFailures(session, invariants, 'before-capture'));
  if (renderCase.policy.skipPixel) {
    test.info().annotations.push({ type: 'pixel skipped', description: renderCase.policy.skipPixel });
  } else {
    await expectMatchesGoldens(session);
  }
  assertNone(await invariantFailures(session, invariants, 'after-capture'));
}

function assertNone(failures: string[]): void {
  if (failures.length > 0) throw new Error(failures.join('\n'));
}
