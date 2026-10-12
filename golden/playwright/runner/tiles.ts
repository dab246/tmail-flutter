import type { RenderCase } from './types';

/**
 * Tallest viewport, hence tallest screenshot. Longer emails are compared in
 * several tiles, never truncated; smaller tiles keep each WebKit capture fast
 * enough under linux/amd64 emulation.
 */
export const MAX_VIEWPORT_HEIGHT = 10_000;

/** Smallest golden, so an empty render still shows its padding and size. */
export const MIN_HEIGHT = 200;

export type Tile = { index: number; top: number; height: number };

/** Tiles covering [contentHeight], each at most [cap] tall. */
export function tilesFor(contentHeight: number, cap = MAX_VIEWPORT_HEIGHT): Tile[] {
  const height = Math.max(Math.ceil(contentHeight), MIN_HEIGHT);
  const count = Math.ceil(height / cap);
  return Array.from({ length: count }, (_, index) => ({
    index,
    top: index * cap,
    height: Math.min(cap, height - index * cap),
  }));
}

/**
 * Clip of [tile] inside the viewport once scrolled to [scrollY]. The browser
 * clamps the last scroll, so the tile may start below the viewport top.
 */
export function clipFor(tile: Tile, scrollY: number, width: number) {
  return { x: 0, y: tile.top - scrollY, width, height: tile.height };
}

/**
 * Characters Playwright replaces in snapshot names. Applying the same rule
 * here keeps the stored file names predictable (`eml_12` → `eml-12`).
 * A single character class with `+`: linear on any input.
 */
const UNSAFE_NAME = /[\x00-\x2C\x2E-\x2F\x3A-\x40\x5B-\x60\x7B-\x7F]+/g;

export const safeName = (name: string): string => name.replace(UNSAFE_NAME, '-');

/** Folder and file stem of a case's goldens, without tile suffix or extension. */
export function goldenStem(renderCase: RenderCase): string[] {
  return [
    safeName(renderCase.target),
    String(renderCase.width),
    safeName(`${renderCase.state}-${renderCase.direction}`),
    safeName(renderCase.fixture),
  ];
}

/** Golden path segments: `<target>/<width>/<state>-<dir>/<fixture>[-t<k>].png`. */
export function snapshotPath(renderCase: RenderCase, tile: Tile, tileCount: number): string[] {
  const stem = goldenStem(renderCase);
  const file = tileCount === 1 ? `${stem[3]}.png` : `${stem[3]}-t${tile.index}.png`;
  return [...stem.slice(0, 3), file];
}

/** Stored goldens (relative paths) that no case of [cases] can produce. */
export function orphanGoldens(stored: string[], cases: RenderCase[]): string[] {
  const stems = new Set(cases.map((c) => goldenStem(c).join('/')));
  return stored.filter((file) => !stems.has(stemOf(file)));
}

/** `a/b/eml-1-t2.png` → `a/b/eml-1`; plain string code, no regex backtracking. */
function stemOf(file: string): string {
  const withoutExtension = file.endsWith('.png') ? file.slice(0, -'.png'.length) : file;
  const tile = withoutExtension.lastIndexOf('-t');
  const suffix = tile < 0 ? '' : withoutExtension.slice(tile + 2);
  const isTileSuffix = suffix.length > 0 && [...suffix].every((ch) => ch >= '0' && ch <= '9');
  return isTileSuffix ? withoutExtension.slice(0, tile) : withoutExtension;
}
