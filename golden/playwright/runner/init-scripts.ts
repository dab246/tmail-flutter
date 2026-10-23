import type { InitScript } from './types';

/**
 * Lazy images start loading at DOMContentLoaded, so the viewer's first layout
 * pass already sees every image size instead of re-running at random times.
 */
export const eagerImages: InitScript = {
  name: 'eager-images',
  script: () => {
    document.addEventListener('DOMContentLoaded', () => {
      document.querySelectorAll('img[loading="lazy"]').forEach((img) => img.setAttribute('loading', 'eager'));
    });
  },
};

/**
 * In the app the webview or iframe is sized to its content, so no scrollbar
 * takes layout width. Hiding them matches that and keeps tiles aligned.
 */
export const hideScrollbars: InitScript = {
  name: 'hide-scrollbars',
  script: () => {
    document.addEventListener('DOMContentLoaded', () => {
      const style = document.createElement('style');
      style.textContent = '::-webkit-scrollbar{display:none}html{scrollbar-width:none}';
      document.head.appendChild(style);
    });
  },
};

export const commonInitScripts: InitScript[] = [eagerImages, hideScrollbars];

/** Calls the page made to the Flutter bridge, recorded by [flutterInAppWebViewBridge]. */
export const BRIDGE_CALLS = '__goldenBridgeCalls';

/**
 * Stands in for `flutter_inappwebview`'s JS bridge. Viewer scripts call
 * `window.flutter_inappwebview.callHandler(...)` without a guard; without the
 * stub every call throws and a real script error could not be told apart.
 */
export const flutterInAppWebViewBridge: InitScript = {
  name: 'flutter-inappwebview-bridge',
  arg: BRIDGE_CALLS,
  script: (key) => {
    const calls: string[] = [];
    const target = window as unknown as Record<string, unknown>;
    target[key as string] = calls;
    target.flutter_inappwebview = {
      callHandler: (name: string) => {
        calls.push(name);
        return Promise.resolve(null);
      },
    };
  },
};
