import { BRIDGE_CALLS, flutterInAppWebViewBridge } from '../../../playwright/runner/init-scripts';
import type { BrowserTarget, CaseSession, InitScript, PageInvariant, RenderCase, SuitePlugin } from '../../../playwright/runner/types';

/** Mirrors `EmailViewTarget` in lib/src/email_view_target.dart. */
const targets: BrowserTarget[] = [
  { id: 'native-android', engine: 'chromium', mobile: true, fontProfile: 'android' },
  { id: 'native-ios', engine: 'webkit', mobile: true, fontProfile: 'ios' },
  { id: 'web', engine: 'chromium', mobile: false, fontProfile: 'web' },
  { id: 'ios-previewer', engine: 'webkit', mobile: true, fontProfile: 'ios' },
];

const isMobileTarget = (c: RenderCase): boolean => c.target !== 'web';

const overflowAllowed = (c: RenderCase): boolean => c.policy.allowHorizontalOverflow.includes(c.target);

/** Shows quoted content from the first layout; the click handler is checked by [quoteToggleWorks]. */
const expandQuotes: InitScript = {
  name: 'expand-quotes',
  script: () => {
    document.addEventListener('DOMContentLoaded', () => {
      document.querySelectorAll('.quote-toggle-button.collapsed').forEach((b) => b.classList.remove('collapsed'));
    });
  },
};

/** A phone viewer must not scroll sideways unless the suite policy allows it. */
const noHorizontalOverflow: PageInvariant = {
  id: 'no-horizontal-overflow',
  phase: 'before-capture',
  appliesTo: (c) => isMobileTarget(c) && !overflowAllowed(c),
  check: async ({ page }) => {
    const { scrollWidth, innerWidth } = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      innerWidth: window.innerWidth,
    }));
    return scrollWidth <= innerWidth ? null : `page is ${scrollWidth}px wide in a ${innerWidth}px viewer`;
  },
};

/** Mirrors `EmailViewRenderSuite.webFontPath`: the only files a viewer may fail to load. */
const DESIGN_FONTS = '/assets/packages/linagora_design_flutter/assets/fonts/';

/**
 * Native viewers load documents without a base URL, so the design fonts 404
 * there like on a device; anything else missing is a broken export.
 */
const onlyDesignFontsMissing: PageInvariant = {
  id: 'only-design-fonts-missing',
  phase: 'before-capture',
  appliesTo: () => true,
  check: async ({ renderCase, record }) => {
    const allowed = (file: string) => renderCase.target !== 'web' && file.includes(DESIGN_FONTS);
    const unexpected = record.missingFiles.filter((file) => !allowed(file));
    return unexpected.length === 0 ? null : `missing: ${unexpected.slice(0, 5).join(', ')}`;
  },
};

/** The Android viewer sizes its WebView from the content-size channel. */
const contentSizeReported: PageInvariant = {
  id: 'content-size-reported',
  phase: 'before-capture',
  appliesTo: (c) => c.target === 'native-android',
  check: async ({ page }) => {
    const calls = await page.evaluate((key) => (window as unknown as Record<string, string[]>)[key] ?? [], BRIDGE_CALLS);
    return calls.includes('ContentSizeChangedEventListener') ? null : 'the content-size channel was never called';
  },
};

/**
 * The web app serves its design font and the document declares it. A face
 * loads only when text uses it, and emails often style all their text, so
 * the font is loaded explicitly: no face, or a face that fails, is an error.
 */
const designFontLoadable: PageInvariant = {
  id: 'design-font-loadable',
  phase: 'before-capture',
  appliesTo: (c) => c.target === 'web',
  check: async ({ page }) => {
    const faces = await page.evaluate(async () => {
      const loaded = await document.fonts.load('14px TwakeInter');
      return loaded.map((face) => face.status);
    });
    if (faces.length === 0) return 'no @font-face declares TwakeInter';
    return faces.every((status) => status === 'loaded') ? null : `TwakeInter faces: ${faces.join(', ')}`;
  },
};

/** Clicking a collapsed toggle reveals the quote it hides; runs after the screenshot. */
const quoteToggleWorks: PageInvariant = {
  id: 'quote-toggle-works',
  phase: 'after-capture',
  appliesTo: (c) => c.state === 'collapsed' && c.target !== 'ios-previewer',
  check: async ({ page }: CaseSession) => {
    const shown = await page.evaluate(() => {
      const button = document.querySelector<HTMLElement>('.quote-toggle-button.collapsed');
      if (!button) return null;
      button.click();
      const quote = button.nextElementSibling;
      return quote !== null && getComputedStyle(quote).display !== 'none';
    });
    return shown === false ? 'clicking the quote toggle did not reveal the quote' : null;
  },
};

const plugin: SuitePlugin = {
  id: 'email_view_html',
  targets,
  initScripts: (c) => [
    ...(c.target === 'web' ? [] : [flutterInAppWebViewBridge]),
    ...(c.state === 'expanded' ? [expandQuotes] : []),
  ],
  invariants: [onlyDesignFontsMissing, noHorizontalOverflow, contentSizeReported, designFontLoadable, quoteToggleWorks],
};

export default plugin;
