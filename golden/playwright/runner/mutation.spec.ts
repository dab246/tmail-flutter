import { test } from '@playwright/test';
import type { BrowserContext } from '@playwright/test';

import { differsFromGoldens } from './capture';
import { genericInvariants, invariantFailures } from './invariants';
import { openCase } from './session';
import { loadExport, loadPlugins, tagOf } from './suites';
import type { MutantCase, RenderCase, SuiteExport, SuitePlugin } from './types';

/**
 * Proves the pixel goldens can fail: each mutant document drops one block
 * the viewer injects, and on every target it applies to, at least one case
 * must break an invariant or differ from its golden. A survivor fails here.
 */
for (const plugin of loadPlugins()) {
  const suiteExport = loadExport(plugin);
  for (const mutant of suiteExport.mutants) {
    for (const [target, cases] of byTarget(suiteExport, mutant.cases)) {
      test(`${mutant.id} SHOULD be detected on ${target}`, { tag: tagOf(plugin.id, target) }, async ({ context }) => {
        const killer = await firstKiller(context, plugin, suiteExport, cases);
        if (killer === null) throw new Error(`"${mutant.id}" survived on ${target}: no case broke or changed`);
        test.info().annotations.push({ type: 'killed by', description: killer });
      });
    }
  }
}

function byTarget(suiteExport: SuiteExport, cases: MutantCase[]): Map<string, MutantCase[]> {
  const groups = new Map<string, MutantCase[]>();
  for (const mutantCase of cases) {
    const target = caseOf(suiteExport, mutantCase).target;
    groups.set(target, [...(groups.get(target) ?? []), mutantCase]);
  }
  return groups;
}

function caseOf(suiteExport: SuiteExport, mutantCase: MutantCase): RenderCase {
  const renderCase = suiteExport.cases.find((c) => c.id === mutantCase.caseId);
  if (!renderCase) throw new Error(`mutant case ${mutantCase.caseId} is not an exported case`);
  return renderCase;
}

/** `<case id>: <why>` of the first case the mutant breaks or changes, or null. */
async function firstKiller(
  context: BrowserContext,
  plugin: SuitePlugin,
  suiteExport: SuiteExport,
  cases: MutantCase[],
): Promise<string | null> {
  for (const mutantCase of cases) {
    const page = await context.newPage();
    try {
      const reason = await detection(page, plugin, suiteExport, mutantCase);
      if (reason !== null) return `${mutantCase.caseId}: ${reason}`;
    } finally {
      await page.close();
    }
  }
  return null;
}

async function detection(
  page: Awaited<ReturnType<BrowserContext['newPage']>>,
  plugin: SuitePlugin,
  suiteExport: SuiteExport,
  mutantCase: MutantCase,
): Promise<string | null> {
  const renderCase = caseOf(suiteExport, mutantCase);
  const session = await openCase(page, { plugin, suiteExport, renderCase, documentPath: mutantCase.document });
  const invariants = [...genericInvariants, ...plugin.invariants];
  const before = await invariantFailures(session, invariants, 'before-capture');
  if (before.length > 0) return before.join('; ');
  if (await differsFromGoldens(session, plugin.id)) return 'pixels differ from the golden';
  const after = await invariantFailures(session, invariants, 'after-capture');
  return after.length > 0 ? after.join('; ') : null;
}
