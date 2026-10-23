import type { Page } from '@playwright/test';

import { MAX_VIEWPORT_HEIGHT } from './tiles';
import { commonInitScripts } from './init-scripts';
import { ORIGIN } from './paths';
import { routeOffline } from './routes';
import type { CaseRequest, CaseSession, PageRecord } from './types';

/**
 * How long the content height may keep changing before a case fails. A real
 * layout loop never settles; a busy emulated machine only renders slowly.
 */
const SETTLE_TIMEOUT_MS = 15_000;

/** Frames the height must stay unchanged to count as settled. */
const STABLE_FRAMES = 2;

/** Browsers log every failed load as console.error; routes.ts records those as missingFiles. */
const RESOURCE_LOAD_ERROR = 'Failed to load resource';

function recordPage(page: Page): PageRecord {
  const record: PageRecord = { errors: [], blockedRequests: [], missingFiles: [] };
  page.on('pageerror', (error) => record.errors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() !== 'error' || message.text().startsWith(RESOURCE_LOAD_ERROR)) return;
    record.errors.push(`console.error: ${message.text()}`);
  });
  return record;
}

/** Fonts, image decoding, then a content height that stops moving. */
export async function settle(page: Page): Promise<void> {
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map((img) => img.decode().catch(() => undefined)));
  });
  await page.evaluate(
    async ({ timeout, frames }) => {
      const nextFrame = () => new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
      const start = performance.now();
      let last = -1;
      let stable = 0;
      while (stable < frames) {
        await nextFrame();
        const height = document.documentElement.scrollHeight;
        stable = height === last ? stable + 1 : 0;
        last = height;
        if (performance.now() - start > timeout) throw new Error(`content height still changing after ${timeout}ms`);
      }
    },
    { timeout: SETTLE_TIMEOUT_MS, frames: STABLE_FRAMES },
  );
}

const contentHeight = (page: Page): Promise<number> =>
  page.evaluate(() => Math.ceil(document.body.getBoundingClientRect().bottom));

/**
 * Loads the requested document: measured at a first size, then reloaded in a
 * viewport taller than the content, because resizing a loaded page would
 * re-run the viewer's responsive layout while a reload lays out once, at the
 * final size.
 */
export async function openCase(page: Page, request: CaseRequest): Promise<CaseSession> {
  const { plugin, suiteExport, renderCase, documentPath } = request;
  const record = recordPage(page);
  await routeOffline(page, suiteExport.dir, record);
  for (const init of [...commonInitScripts, ...plugin.initScripts(renderCase)]) {
    await page.addInitScript(init.script, init.arg);
  }
  await page.setViewportSize({ width: renderCase.width, height: 800 });
  await page.goto(`${ORIGIN}/${documentPath}`, { waitUntil: 'load' });
  await settle(page);
  const measured = await contentHeight(page);
  await page.setViewportSize({ width: renderCase.width, height: Math.min(measured + 400, MAX_VIEWPORT_HEIGHT) });
  await page.reload({ waitUntil: 'load' });
  await settle(page);
  return { page, renderCase, record, height: await contentHeight(page) };
}
