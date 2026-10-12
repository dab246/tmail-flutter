import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { expect, test } from '@playwright/test';

import { loadExport, pixelSuiteIds, tagOf } from '../runner/suites';
import type { SuitePlugin } from '../runner/types';

const plugin: SuitePlugin = {
  id: 'demo',
  targets: [{ id: 'web', engine: 'chromium', mobile: false, fontProfile: 'web' }],
  initScripts: () => [],
  invariants: [],
};

function tempDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'golden-runner-'));
}

function writeJson(file: string, json: unknown): void {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(json));
}

const exportOf = (overrides: Record<string, unknown>) => ({
  schemaVersion: 1,
  suite: 'demo',
  cases: [{ id: 'web/1000/collapsed-ltr/eml_1', target: 'web' }],
  mutants: [],
  ...overrides,
});

test('pixelSuiteIds SHOULD list only suites that declare pixel goldens', () => {
  const dir = tempDir();
  writeJson(path.join(dir, 'a/suite.json'), { id: 'a', kinds: ['text', 'pixel'] });
  writeJson(path.join(dir, 'b/suite.json'), { id: 'b', kinds: ['text'] });
  fs.mkdirSync(path.join(dir, 'c'));

  expect(pixelSuiteIds(dir)).toEqual(['a']);
});

test('loadExport SHOULD read a valid export', () => {
  const dir = tempDir();
  writeJson(path.join(dir, 'demo/cases.json'), exportOf({}));

  expect(loadExport(plugin, dir).cases).toHaveLength(1);
});

const invalidExports: [string, Record<string, unknown> | null, string][] = [
  ['the export is missing', null, 'is missing'],
  ['the schema version is unknown', { schemaVersion: 2 }, 'schemaVersion 2'],
  ['the export belongs to another suite', { suite: 'other' }, 'belongs to other'],
  ['a case uses an undeclared target', { cases: [{ id: 'x', target: 'ios' }] }, 'targets the plugin does not declare: ios'],
  ['there is no case', { cases: [] }, 'has no cases'],
];

for (const [problem, overrides, message] of invalidExports) {
  test(`loadExport SHOULD fail loudly WHEN ${problem}`, () => {
    const dir = tempDir();
    if (overrides) writeJson(path.join(dir, 'demo/cases.json'), exportOf(overrides));

    expect(() => loadExport(plugin, dir)).toThrow(message);
  });
}

test('tagOf SHOULD name the suite and the target', () => {
  expect(tagOf('email_view_html', 'native-ios')).toBe('@email_view_html:native-ios');
});
