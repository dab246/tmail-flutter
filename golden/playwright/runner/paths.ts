import path from 'node:path';

/** `golden/` — the runner lives in `golden/playwright/runner/`. */
export const GOLDEN_DIR = path.resolve(__dirname, '..', '..');

export const SUITES_DIR = path.join(GOLDEN_DIR, 'suites');

/** Where `golden/run.sh` makes the Dart suites export their documents. */
export const EXPORT_DIR = process.env.GOLDEN_EXPORT_DIR ?? path.join(GOLDEN_DIR, 'playwright', '.export');

/** Origin the documents are served from; nothing else is reachable. */
export const ORIGIN = 'http://render.test';

export const FONTCONFIG_DIR = path.join(GOLDEN_DIR, 'playwright', 'fontconfig');

export const pixelGoldensDir = (suiteId: string): string => path.join(SUITES_DIR, suiteId, 'goldens', 'pixel');
