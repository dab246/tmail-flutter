import type { Page } from '@playwright/test';

/** Mirrors `FixturePolicy.toJson()` in golden_kit. */
export type Policy = {
  maxMissingTextTokens: number;
  maxLostLinks: number;
  maxLostImages: number;
  allowHorizontalOverflow: string[];
  skipPixel: string | null;
};

/** Mirrors `RenderCase.toJson()` in golden_kit. */
export type RenderCase = {
  id: string;
  target: string;
  fixture: string;
  width: number;
  state: string;
  direction: 'ltr' | 'rtl';
  document: string;
  policy: Policy;
};

export type MutantCase = { caseId: string; document: string };

export type DocumentMutant = { id: string; cases: MutantCase[] };

/** `cases.json` of one suite, with the folder it was read from. */
export type SuiteExport = {
  suite: string;
  dir: string;
  cases: RenderCase[];
  mutants: DocumentMutant[];
};

export type Engine = 'chromium' | 'webkit';

/** Which system fonts stand in for the device's `sans-serif`. */
export type FontProfile = 'android' | 'ios' | 'web';

export type BrowserTarget = {
  id: string;
  engine: Engine;
  /** Honors `<meta name="viewport">`, touch and overlay scrollbars like a phone webview. */
  mobile: boolean;
  fontProfile: FontProfile;
};

/** A function serialized into the page before any of its scripts run. */
export type InitScript = { name: string; script: (arg: unknown) => void; arg?: unknown };

/** What happened in the page while a case loaded. */
export type PageRecord = {
  /** Uncaught errors, rejections and `console.error` other than resource loads. */
  errors: string[];
  /** Requests outside the export that were blocked (the page wanted the network). */
  blockedRequests: string[];
  /** Export paths the document asked for that do not exist (answered 404). */
  missingFiles: string[];
};

/** One document to load as one case of one suite. */
export type CaseRequest = {
  plugin: SuitePlugin;
  suiteExport: SuiteExport;
  renderCase: RenderCase;
  /** The case's own document, or one of its mutants. */
  documentPath: string;
};

export type CaseSession = {
  page: Page;
  renderCase: RenderCase;
  record: PageRecord;
  /** Content height of the loaded document, in CSS pixels. */
  height: number;
};

/**
 * A rule a rendered case must satisfy. `before-capture` invariants only read
 * the page; `after-capture` ones may interact with it (e.g. click a toggle).
 */
export type PageInvariant = {
  id: string;
  phase: 'before-capture' | 'after-capture';
  appliesTo(renderCase: RenderCase): boolean;
  /** Null when satisfied, otherwise why not. */
  check(session: CaseSession): Promise<string | null>;
};

/** What a suite adds to the generic runner. */
export type SuitePlugin = {
  id: string;
  targets: BrowserTarget[];
  initScripts(renderCase: RenderCase): InitScript[];
  invariants: PageInvariant[];
};
