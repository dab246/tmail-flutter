import fs from 'node:fs';
import path from 'node:path';

import { EXPORT_DIR, SUITES_DIR } from './paths';
import type { RenderCase, SuiteExport, SuitePlugin } from './types';

const SCHEMA_VERSION = 1;

type SuiteDescriptor = { id: string; kinds: string[] };

const readJson = <T>(file: string): T => JSON.parse(fs.readFileSync(file, 'utf8')) as T;

/** Suites whose `suite.json` declares pixel goldens. */
export function pixelSuiteIds(suitesDir = SUITES_DIR): string[] {
  return fs
    .readdirSync(suitesDir)
    .map((name) => path.join(suitesDir, name, 'suite.json'))
    .filter((file) => fs.existsSync(file))
    .map((file) => readJson<SuiteDescriptor>(file))
    .filter((suite) => suite.kinds.includes('pixel'))
    .map((suite) => suite.id)
    .sort();
}

/** The plugin of every pixel suite; a pixel suite without one is an error. */
export function loadPlugins(suitesDir = SUITES_DIR): SuitePlugin[] {
  return pixelSuiteIds(suitesDir).map((id) => {
    const file = path.join(suitesDir, id, 'playwright', 'suite.ts');
    if (!fs.existsSync(file)) throw new Error(`${id} declares pixel goldens but has no ${file}`);
    const plugin = (require(file) as { default: SuitePlugin }).default;
    if (plugin?.id !== id) throw new Error(`${file} must export default a plugin with id "${id}"`);
    return plugin;
  });
}

/** Reads and checks a suite export; a missing or inconsistent one is an error, never "0 tests". */
export function loadExport(plugin: SuitePlugin, exportDir = EXPORT_DIR): SuiteExport {
  const dir = path.join(exportDir, plugin.id);
  const file = path.join(dir, 'cases.json');
  if (!fs.existsSync(file)) throw new Error(`${file} is missing: run golden/run.sh, which exports before rendering`);
  const json = readJson<ExportJson>(file);
  assertValidExport(json, plugin, file);
  return { suite: json.suite, dir, cases: json.cases, mutants: json.mutants ?? [] };
}

type ExportJson = { schemaVersion: number } & Omit<SuiteExport, 'dir'>;

function assertValidExport(json: ExportJson, plugin: SuitePlugin, file: string): void {
  if (json.schemaVersion !== SCHEMA_VERSION) {
    throw new Error(`${file}: schemaVersion ${json.schemaVersion}, runner expects ${SCHEMA_VERSION}`);
  }
  if (json.suite !== plugin.id) throw new Error(`${file} belongs to ${json.suite}, not ${plugin.id}`);
  assertKnownTargets(plugin, json.cases);
  if (json.cases.length === 0) throw new Error(`${file} has no cases`);
}

function assertKnownTargets(plugin: SuitePlugin, cases: RenderCase[]): void {
  const known = new Set(plugin.targets.map((t) => t.id));
  const unknown = [...new Set(cases.map((c) => c.target))].filter((t) => !known.has(t));
  if (unknown.length > 0) throw new Error(`${plugin.id}: cases use targets the plugin does not declare: ${unknown}`);
}

/** Tag that routes a test to the project of its suite and target. */
export const tagOf = (suiteId: string, targetId: string): string => `@${suiteId}:${targetId}`;
