/**
 * Type declarations for VSCode Webview API globals.
 * These are available in the webview context.
 */

declare const acquireVsCodeApi: () => {
  postMessage: (message: unknown) => void;
  getState: <T = unknown>() => T | undefined;
  setState: <T = unknown>(state: T) => T;
};
