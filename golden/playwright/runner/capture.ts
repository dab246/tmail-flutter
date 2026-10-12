import fs from 'node:fs';
import path from 'node:path';

import { expect } from '@playwright/test';

import { pixelGoldensDir } from './paths';
import { clipFor, snapshotPath, tilesFor } from './tiles';
import type { CaseSession } from './types';

/** Scrolls to each tile of the session and hands its golden name and clip to [visit]. */
async function forEachTile(
  session: CaseSession,
  visit: (name: string[], clip: ReturnType<typeof clipFor>) => Promise<void>,
): Promise<void> {
  const tiles = tilesFor(session.height);
  for (const tile of tiles) {
    const scrollY = await session.page.evaluate((top) => {
      window.scrollTo(0, top);
      return window.scrollY;
    }, tile.top);
    await visit(snapshotPath(session.renderCase, tile, tiles.length), clipFor(tile, scrollY, session.renderCase.width));
  }
}

/** Compares every tile with its golden; fails the test on the first difference. */
export async function expectMatchesGoldens(session: CaseSession): Promise<void> {
  await forEachTile(session, (name, clip) => expect(session.page).toHaveScreenshot(name, { clip }));
}

/**
 * True when any tile differs from the case's stored golden. Used by mutation
 * runs, which must never write a golden: a missing golden is an error.
 */
export async function differsFromGoldens(session: CaseSession, suiteId: string): Promise<boolean> {
  let differs = false;
  await forEachTile(session, async (name, clip) => {
    if (differs) return;
    const golden = path.join(pixelGoldensDir(suiteId), ...name);
    if (!fs.existsSync(golden)) throw new Error(`${golden} is missing: render the goldens before mutating`);
    try {
      await expect(session.page).toHaveScreenshot(name, { clip, timeout: 10_000 });
    } catch {
      differs = true;
    }
  });
  return differs;
}
