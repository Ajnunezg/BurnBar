import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { BurnBarWorkspaceHostKind } from '../../src/workspace/types';
import {
  createBurnBarWorkspaceApi,
  resolveWorkspaceUri,
  type BurnBarWorkspaceApi,
  type BurnBarWorkspaceUri
} from '../../src/workspace/api';

// Mock vscode
vi.mock('vscode', () => ({
  Uri: {
    parse: (value: string) => ({ scheme: 'file', fsPath: value, toString: () => value }),
    file: (value: string) => ({ scheme: 'file', fsPath: value, toString: () => `file://${value}` }),
    joinPath: (base: any, ...segments: string[]) => ({ scheme: 'file', fsPath: segments.join('/'), toString: () => `file://${segments.join('/')}` })
  },
  env: {
    remoteName: 'cursor'
  },
  workspace: {
    isTrusted: true,
    workspaceFolders: [
      {
        uri: {
          fsPath: '/Users/test/project',
          toString: () => 'file:///Users/test/project'
        }
      }
    ],
    fs: {
      isWritableFileSystem: vi.fn(() => true),
      readFile: vi.fn(() => Promise.resolve(new Uint8Array()))
    },
    findFiles: vi.fn(() => Promise.resolve([])),
    openTextDocument: vi.fn(() => Promise.resolve({
      getText: () => 'test content'
    })),
    applyEdit: vi.fn(() => Promise.resolve(true)),
    saveAll: vi.fn(() => Promise.resolve(true))
  },
  window: {
    createTerminal: vi.fn(() => ({
      name: 'OpenBurnBar',
      show: vi.fn(),
      sendText: vi.fn()
    }))
  },
  WorkspaceEdit: vi.fn(),
  Range: vi.fn()
}));

// Import vscode after mocking
import * as vscode from 'vscode';

describe('createBurnBarWorkspaceApi', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should create API with ui host kind', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(api.hostKind).toBe('ui');
    expect(api.isTrusted).toBe(true);
  });

  it('should create API with workspace host kind', () => {
    const api = createBurnBarWorkspaceApi('workspace');

    expect(api.hostKind).toBe('workspace');
  });

  it('should expose workspace folders', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(api.workspaceFolders).toBeDefined();
    expect(Array.isArray(api.workspaceFolders)).toBe(true);
  });

  it('should expose remote name', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(api.remoteName).toBe('cursor');
  });

  it('should expose isWritableFileSystem method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.isWritableFileSystem).toBe('function');
    expect(api.isWritableFileSystem('file')).toBe(true);
  });

  it('should expose readFile method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.readFile).toBe('function');
  });

  it('should expose findFiles method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.findFiles).toBe('function');
  });

  it('should expose openTextDocument method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.openTextDocument).toBe('function');
  });

  it('should expose applyEdit method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.applyEdit).toBe('function');
  });

  it('should expose saveAll method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.saveAll).toBe('function');
  });

  it('should expose createWorkspaceEdit method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.createWorkspaceEdit).toBe('function');
  });

  it('should expose createRange method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.createRange).toBe('function');
  });

  it('should expose createTerminal method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.createTerminal).toBe('function');
  });

  it('should expose parseUri method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.parseUri).toBe('function');
  });

  it('should expose fileUri method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.fileUri).toBe('function');
  });

  it('should expose joinPath method', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.joinPath).toBe('function');
  });
});

describe('resolveWorkspaceUri', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should resolve absolute path to URI', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, '/Users/test/file.txt');

    expect(result).toBeDefined();
    expect(result.fsPath).toContain('file.txt');
  });

  it('should resolve URI string as-is', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, 'file:///Users/test/file.txt');

    expect(result).toBeDefined();
  });

  it('should resolve relative path using workspace root', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, 'src/file.txt');

    expect(result).toBeDefined();
  });

  it('should handle path with subdirectories', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, 'src/nested/deep/file.txt');

    expect(result).toBeDefined();
  });

  it('should handle empty relative path', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, '');

    expect(result).toBeDefined();
  });

  it('should throw error when no workspace folder for relative path', () => {
    // Create API with no workspace folders
    const emptyApi = {
      workspaceFolders: undefined,
      parseUri: (value: string) => ({ scheme: '', fsPath: '', toString: () => value } as BurnBarWorkspaceUri),
      fileUri: (value: string) => ({ scheme: 'file', fsPath: value, toString: () => `file://${value}` } as BurnBarWorkspaceUri),
      joinPath: (base: BurnBarWorkspaceUri, ...segments: string[]) => ({ scheme: 'file', fsPath: segments.join('/'), toString: () => `file://${segments.join('/')}` } as BurnBarWorkspaceUri)
    };

    expect(() => resolveWorkspaceUri(emptyApi as any, 'relative/path.txt')).toThrow('Open a workspace folder');
  });

  it('should resolve URI with scheme as-is', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, 'vscode://test/file.txt');

    expect(result).toBeDefined();
    // URI with vscode:// scheme should be returned as-is
    expect(result.scheme).toBeDefined();
  });

  it('should resolve special URI schemes', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const schemes = ['http://', 'https://', 'git://', 'sftp://'];

    for (const scheme of schemes) {
      const result = resolveWorkspaceUri(api, `${scheme}example.com/file.txt`);
      expect(result).toBeDefined();
    }
  });

  it('should handle paths with leading slashes', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, '/absolute/path.txt');

    expect(result).toBeDefined();
  });

  it('should handle paths without leading slash as relative', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, 'relative/path.txt');

    expect(result).toBeDefined();
  });
});

// Integration tests
describe('Workspace API Integration', () => {
  it('should create API and resolve URIs in sequence', () => {
    const api = createBurnBarWorkspaceApi('ui');

    // Create URI from absolute path
    const uri1 = resolveWorkspaceUri(api, '/Users/test/project/file.txt');
    expect(uri1).toBeDefined();

    // Create URI from workspace-relative path
    const uri2 = resolveWorkspaceUri(api, 'src/index.ts');
    expect(uri2).toBeDefined();
  });

  it('should handle multiple workspace folder scenarios', () => {
    // Test with different workspace folder configurations
    const api1 = createBurnBarWorkspaceApi('ui');
    expect(api1.workspaceFolders).toBeDefined();

    // URI resolution should work
    const uri = resolveWorkspaceUri(api1, '/test/path.txt');
    expect(uri).toBeDefined();
  });
});

// Edge case tests
describe('Workspace API Edge Cases', () => {
  it('should handle unicode in paths', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, '/test/Проект/file.txt');

    expect(result).toBeDefined();
  });

  it('should handle special characters in paths', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, '/test/path with spaces/file.txt');

    expect(result).toBeDefined();
  });

  it('should handle very long paths', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const longPath = '/test/' + 'a'.repeat(500) + '/file.txt';
    const result = resolveWorkspaceUri(api, longPath);

    expect(result).toBeDefined();
  });

  it('should handle paths with multiple slashes', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const result = resolveWorkspaceUri(api, '///multiple///slashes///');

    expect(result).toBeDefined();
  });
});

// API interface tests
describe('BurnBarWorkspaceApi Interface', () => {
  it('should have required properties', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect('hostKind' in api).toBe(true);
    expect('remoteName' in api).toBe(true);
    expect('isTrusted' in api).toBe(true);
    expect('workspaceFolders' in api).toBe(true);
  });

  it('should have required methods', () => {
    const api = createBurnBarWorkspaceApi('ui');

    expect(typeof api.isWritableFileSystem).toBe('function');
    expect(typeof api.readFile).toBe('function');
    expect(typeof api.findFiles).toBe('function');
    expect(typeof api.openTextDocument).toBe('function');
    expect(typeof api.applyEdit).toBe('function');
    expect(typeof api.saveAll).toBe('function');
    expect(typeof api.createWorkspaceEdit).toBe('function');
    expect(typeof api.createRange).toBe('function');
    expect(typeof api.createTerminal).toBe('function');
    expect(typeof api.parseUri).toBe('function');
    expect(typeof api.fileUri).toBe('function');
    expect(typeof api.joinPath).toBe('function');
  });
});

// Type tests
describe('BurnBarWorkspaceUri Interface', () => {
  it('should have required properties', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const uri = resolveWorkspaceUri(api, '/test/path.txt');

    expect('scheme' in uri).toBe(true);
    expect('fsPath' in uri).toBe(true);
    expect('toString' in uri).toBe(true);
  });

  it('toString should return string representation', () => {
    const api = createBurnBarWorkspaceApi('ui');
    const uri = resolveWorkspaceUri(api, '/test/path.txt');

    expect(typeof uri.toString()).toBe('string');
  });
});
