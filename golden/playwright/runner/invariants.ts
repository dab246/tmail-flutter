import type { CaseSession, PageInvariant } from './types';

/** No uncaught error, rejected promise or `console.error` while the case loaded. */
export const noPageErrors: PageInvariant = {
  id: 'no-page-errors',
  phase: 'before-capture',
  appliesTo: () => true,
  check: async ({ record }) => (record.errors.length === 0 ? null : record.errors.slice(0, 5).join('\n')),
};

export const genericInvariants: PageInvariant[] = [noPageErrors];

/** `[id] message` for every invariant of [phase] that fails on [session]. */
export async function invariantFailures(
  session: CaseSession,
  invariants: PageInvariant[],
  phase: PageInvariant['phase'],
): Promise<string[]> {
  const failures: string[] = [];
  for (const invariant of invariants) {
    if (invariant.phase !== phase || !invariant.appliesTo(session.renderCase)) continue;
    const message = await invariant.check(session);
    if (message !== null) failures.push(`[${invariant.id}] ${message}`);
  }
  return failures;
}

/** Soft metrics attached to the report to explain a pixel diff; never a gate. */
export async function collectMetrics(session: CaseSession): Promise<Record<string, unknown>> {
  const page = await session.page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
    images: document.images.length,
    links: document.querySelectorAll('a[href]').length,
  }));
  const { blockedRequests, missingFiles } = session.record;
  return { height: session.height, blockedRequests: blockedRequests.length, missingFiles: missingFiles.length, ...page };
}
