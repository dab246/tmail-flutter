import path from 'node:path';

import { expect, test } from '@playwright/test';

import { exportFileFor, placeholderSize } from '../runner/routes';

test.describe('placeholderSize', () => {
  test('SHOULD read the intrinsic size from a scrubbed image URL', () => {
    expect(placeholderSize('https://fixture.invalid/img/640x320?x=1')).toEqual({ width: 640, height: 320 });
    expect(placeholderSize('https://fixture.invalid/cid/76x38')).toEqual({ width: 76, height: 38 });
  });

  test('SHOULD fall back to a default size for any other image URL', () => {
    expect(placeholderSize('https://cdn.example/logo.png')).toEqual({ width: 600, height: 300 });
    expect(placeholderSize('https://fixture.invalid/img/1234567x1')).toEqual({ width: 600, height: 300 });
  });
});

test.describe('exportFileFor', () => {
  const root = path.resolve('/export/email_view_html');

  test('SHOULD map a document URL to a file of the export', () => {
    expect(exportFileFor(root, 'http://render.test/web/1032/ltr/eml_1.html')).toBe(path.join(root, 'web/1032/ltr/eml_1.html'));
  });

  test('SHOULD keep a URL whose dot segments the URL parser already resolved inside the export', () => {
    expect(exportFileFor(root, 'http://render.test/%2e%2e/secret.txt')).toBe(path.join(root, 'secret.txt'));
  });

  test('SHOULD refuse a URL whose encoded slashes escape the export folder', () => {
    expect(exportFileFor(root, 'http://render.test/..%2F..%2Fetc/passwd')).toBeNull();
  });
});
