import fs from 'node:fs';
import path from 'node:path';

import type { Page, Route } from '@playwright/test';

import { ORIGIN } from './paths';
import type { PageRecord } from './types';

/**
 * Scrubbed fixtures point images at `https://fixture.invalid/<kind>/<W>x<H>…`
 * with the original intrinsic size. Digits are bounded, so matching stays linear.
 */
const PLACEHOLDER = /^https:\/\/fixture\.invalid\/(?:img|cid|est)\/(\d{1,5})x(\d{1,5})/;

const FALLBACK_SIZE = { width: 600, height: 300 };

export const placeholderSvg = (width: number, height: number): string =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">` +
  '<rect width="100%" height="100%" fill="#c8c8c8"/></svg>';

/** Size of the gray placeholder served for an image URL. */
export function placeholderSize(url: string): { width: number; height: number } {
  const match = PLACEHOLDER.exec(url);
  return match ? { width: Number(match[1]), height: Number(match[2]) } : FALLBACK_SIZE;
}

/** File under [root] that serves [url], or null when the URL escapes it. */
export function exportFileFor(root: string, url: string): string | null {
  const relative = decodeURIComponent(new URL(url).pathname).replace(/^\/+/, '');
  const file = path.resolve(root, relative);
  return file.startsWith(path.resolve(root) + path.sep) ? file : null;
}

/**
 * Serves the export folder at ORIGIN and nothing else. A missing local file
 * answers 404 like the app's webview (native viewers cannot load the design
 * fonts); images become gray placeholders; any other request is blocked and
 * recorded, so a fixture that depends on the network shows up in the report.
 */
export async function routeOffline(page: Page, exportRoot: string, record: PageRecord): Promise<void> {
  await page.route('**/*', (route) => handle(route, exportRoot, record));
}

function handle(route: Route, exportRoot: string, record: PageRecord): Promise<void> {
  const request = route.request();
  const url = request.url();
  if (url.startsWith(`${ORIGIN}/`)) return serveLocal(route, exportRoot, url, record);
  if (request.resourceType() === 'image') {
    const { width, height } = placeholderSize(url);
    return route.fulfill({ contentType: 'image/svg+xml', body: placeholderSvg(width, height) });
  }
  record.blockedRequests.push(url);
  return route.abort('blockedbyclient');
}

function serveLocal(route: Route, exportRoot: string, url: string, record: PageRecord): Promise<void> {
  const file = exportFileFor(exportRoot, url);
  if (file && fs.existsSync(file)) return route.fulfill({ path: file });
  record.missingFiles.push(new URL(url).pathname);
  return route.fulfill({ status: 404, body: '' });
}
