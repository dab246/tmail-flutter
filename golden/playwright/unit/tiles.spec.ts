import { expect, test } from '@playwright/test';

import { clipFor, MIN_HEIGHT, orphanGoldens, safeName, snapshotPath, tilesFor } from '../runner/tiles';
import type { RenderCase } from '../runner/types';

const renderCase = (fixture = 'eml_12'): RenderCase => ({
  id: `native-android/390/collapsed-ltr/${fixture}`,
  target: 'native-android',
  fixture,
  width: 390,
  state: 'collapsed',
  direction: 'ltr',
  document: 'd.html',
  policy: { maxMissingTextTokens: 0, maxLostLinks: 0, maxLostImages: 0, allowHorizontalOverflow: [], skipPixel: null },
});

test.describe('tilesFor', () => {
  test('SHOULD use one tile up to the cap and never less than the minimum height', () => {
    expect(tilesFor(10)).toEqual([{ index: 0, top: 0, height: MIN_HEIGHT }]);
    expect(tilesFor(10_000)).toEqual([{ index: 0, top: 0, height: 10_000 }]);
  });

  test('SHOULD cover a long page with full tiles and a shorter last one', () => {
    expect(tilesFor(25_000)).toEqual([
      { index: 0, top: 0, height: 10_000 },
      { index: 1, top: 10_000, height: 10_000 },
      { index: 2, top: 20_000, height: 5_000 },
    ]);
  });
});

test('clipFor SHOULD start the last tile below the viewport top WHEN the scroll was clamped', () => {
  const last = { index: 2, top: 20_000, height: 5_000 };

  expect(clipFor(last, 15_000, 390)).toEqual({ x: 0, y: 5_000, width: 390, height: 5_000 });
});

test.describe('golden names', () => {
  test('SHOULD sanitize like Playwright and add a tile suffix only for tiled pages', () => {
    const tile = { index: 2, top: 0, height: 1 };

    expect(safeName('eml_12')).toBe('eml-12');
    expect(snapshotPath(renderCase(), tile, 1)).toEqual(['native-android', '390', 'collapsed-ltr', 'eml-12.png']);
    expect(snapshotPath(renderCase(), tile, 3)).toEqual(['native-android', '390', 'collapsed-ltr', 'eml-12-t2.png']);
  });

  test('SHOULD report stored goldens no case produces', () => {
    const stored = [
      'native-android/390/collapsed-ltr/eml-12.png',
      'native-android/390/collapsed-ltr/eml-12-t1.png',
      'native-android/390/collapsed-ltr/eml-9.png',
      'native-android/390/collapsed-ltr/eml-12-tx.png',
    ];

    expect(orphanGoldens(stored, [renderCase()])).toEqual([
      'native-android/390/collapsed-ltr/eml-9.png',
      'native-android/390/collapsed-ltr/eml-12-tx.png',
    ]);
  });
});
