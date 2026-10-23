import path from 'node:path';

import { defineConfig } from '@playwright/test';
import type { Project } from '@playwright/test';

import { FONTCONFIG_DIR, pixelGoldensDir } from './runner/paths';
import { loadPlugins, tagOf } from './runner/suites';
import type { BrowserTarget, SuitePlugin } from './runner/types';

/** `GOLDEN_MODE=mutation` proves the goldens can fail instead of comparing them. */
const mutationMode = process.env.GOLDEN_MODE === 'mutation';

const escapeRegExp = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** Fonts the target's webview resolves `sans-serif` to (see fontconfig/). */
function fontEnvironment(target: BrowserTarget): Record<string, string> {
  if (target.fontProfile === 'web') return {};
  return { FONTCONFIG_FILE: path.join(FONTCONFIG_DIR, `${target.fontProfile}.conf`) };
}

function projectFor(plugin: SuitePlugin, target: BrowserTarget): Project {
  return {
    name: `${plugin.id}:${target.id}`,
    testMatch: mutationMode ? 'runner/mutation.spec.ts' : 'runner/render.spec.ts',
    grep: new RegExp(`${escapeRegExp(tagOf(plugin.id, target.id))}(?![\\w-])`),
    snapshotPathTemplate: path.join(pixelGoldensDir(plugin.id), '{arg}{ext}'),
    use: {
      browserName: target.engine,
      deviceScaleFactor: 1,
      isMobile: target.mobile,
      hasTouch: target.mobile,
      launchOptions: { env: { ...process.env, ...fontEnvironment(target) } },
    },
  };
}

export default defineConfig({
  testDir: '.',
  // Browser start-up is slow under linux/amd64 emulation on Apple Silicon; pixels stay exact.
  timeout: 300_000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  reporter: [['list'], ['html', { open: 'never' }]],
  expect: {
    // A 10000px WebKit capture under emulation needs more than the default 5s.
    timeout: 30_000,
    toHaveScreenshot: { animations: 'disabled', caret: 'hide', maxDiffPixelRatio: 0 },
  },
  projects: [
    { name: 'runner-unit', testMatch: 'unit/*.spec.ts' },
    ...(mutationMode ? [] : [{ name: 'golden-orphans', testMatch: 'runner/orphans.spec.ts' }]),
    ...loadPlugins().flatMap((plugin) => plugin.targets.map((target) => projectFor(plugin, target))),
  ],
});
