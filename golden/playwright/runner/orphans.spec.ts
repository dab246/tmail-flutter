import fs from 'node:fs';
import path from 'node:path';

import { expect, test } from '@playwright/test';

import { pixelGoldensDir } from './paths';
import { loadExport, loadPlugins } from './suites';
import { orphanGoldens } from './tiles';

const listFiles = (dir: string): string[] =>
  fs.existsSync(dir)
    ? (fs.readdirSync(dir, { recursive: true }) as string[])
        .filter((file) => fs.statSync(path.join(dir, file)).isFile())
        .map((file) => file.split(path.sep).join('/'))
    : [];

/** A golden no exported case produces would never be compared again. */
for (const plugin of loadPlugins()) {
  test(`${plugin.id}: every stored pixel golden SHOULD belong to an exported case`, () => {
    const stored = listFiles(pixelGoldensDir(plugin.id));
    expect(orphanGoldens(stored, loadExport(plugin).cases)).toEqual([]);
  });
}
