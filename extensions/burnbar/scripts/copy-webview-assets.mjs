import { cpSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const extensionRoot = resolve(scriptDir, '..');
const sourceDir = resolve(extensionRoot, 'src', 'webview');
const outputDir = resolve(extensionRoot, 'dist', 'webview');

mkdirSync(outputDir, { recursive: true });
cpSync(sourceDir, outputDir, { recursive: true });
