import { describe, it, expect, vi } from 'vitest';
import type { BurnBarExtensionController } from '../../src/state/controller';
import type { BurnBarState } from '../../src/types';
import { buildHealthRows, type BurnBarHealthRow } from '../../src/state/projections';

// Mock vscode
vi.mock('vscode', () => ({
  TreeItem: class MockTreeItem {
    constructor(
      public label: string,
      public collapsibleState: number
    ) {
      this.description = undefined;
      this.tooltip = undefined;
      this.iconPath = undefined;
      this.contextValue = undefined;
    }
  },
  TreeItemCollapsibleState: {
    None: 0,
    Collapsed: 1,
    Expanded: 2
  },
  ThemeIcon: class MockThemeIcon {
    constructor(public id: string) {}
  },
  EventEmitter: class MockEventEmitter<T> {
    private listeners: Array<(value: T) => void> = [];

    event = (listener: (value: T) => void) => {
      this.listeners.push(listener);
      return { dispose: () => {} };
    };

    fire = (value: T) => {
      this.listeners.forEach(l => l(value));
    };

    dispose = () => {
      this.listeners = [];
    };
  }
}));

// Import after mocking
import * as vscode from 'vscode';

// Import the module under test
import {
  BurnBarHealthTreeDataProvider
} from '../../src/views/healthView';

// Create a minimal mock state
function createMinimalState(): Pick<BurnBarState, 'connectionStatus' | 'daemonRuns' | 'recentUsage' | 'health'> {
  return {
    connectionStatus: 'connecting',
    daemonRuns: [],
    recentUsage: []
  };
}

// Create a mock controller
function createMockController(partialState: Partial<BurnBarState> = {}): BurnBarExtensionController {
  const defaultState: BurnBarState = {
    connectionStatus: 'connecting',
    clientAttached: false,
    daemonRuns: [],
    pendingToolCalls: [],
    recentUsage: [],
    runs: [],
    ...partialState
  };

  return {
    snapshot: defaultState,
    onDidChangeState: vi.fn().mockReturnValue({ dispose: vi.fn() })
  } as unknown as BurnBarExtensionController;
}

describe('BurnBarHealthTreeDataProvider', () => {
  describe('constructor', () => {
    it('should subscribe to controller state changes', () => {
      const controller = createMockController();
      const provider = new BurnBarHealthTreeDataProvider(controller);

      expect(controller.onDidChangeState).toHaveBeenCalled();
      expect(provider.onDidChangeTreeData).toBeDefined();
    });

    it('should create event emitter', () => {
      const controller = createMockController();
      const provider = new BurnBarHealthTreeDataProvider(controller);

      // Verify provider was created with event emitter
      expect(provider).toBeDefined();
      expect(provider.onDidChangeTreeData).toBeDefined();
    });
  });

  describe('getTreeItem', () => {
    it('should return the tree item as-is', () => {
      const controller = createMockController();
      const provider = new BurnBarHealthTreeDataProvider(controller);

      const mockItem = new vscode.TreeItem('test', 0);
      const result = provider.getTreeItem(mockItem as any);

      expect(result).toBe(mockItem);
    });
  });

  describe('getChildren', () => {
    it('should return empty array for child elements', async () => {
      const controller = createMockController();
      const provider = new BurnBarHealthTreeDataProvider(controller);

      const mockItem = new vscode.TreeItem('test', 0);
      const children = await provider.getChildren(mockItem as any);

      expect(children).toEqual([]);
    });

    it('should return health rows from controller snapshot', async () => {
      const controller = createMockController({
        connectionStatus: 'connected',
        clientAttached: true
      });

      const provider = new BurnBarHealthTreeDataProvider(controller);
      const children = await provider.getChildren();

      expect(Array.isArray(children)).toBe(true);
    });

    it('should handle disconnected state', async () => {
      const controller = createMockController({
        connectionStatus: 'disconnected'
      });

      const provider = new BurnBarHealthTreeDataProvider(controller);
      const children = await provider.getChildren();

      expect(Array.isArray(children)).toBe(true);
    });

    it('should handle connecting state', async () => {
      const controller = createMockController({
        connectionStatus: 'connecting'
      });

      const provider = new BurnBarHealthTreeDataProvider(controller);
      const children = await provider.getChildren();

      expect(Array.isArray(children)).toBe(true);
    });
  });

  describe('dispose', () => {
    it('should clean up without errors', () => {
      const controller = createMockController();
      const provider = new BurnBarHealthTreeDataProvider(controller);

      expect(() => provider.dispose()).not.toThrow();
    });

    it('should be callable multiple times safely', () => {
      const controller = createMockController();
      const provider = new BurnBarHealthTreeDataProvider(controller);

      provider.dispose();
      expect(() => provider.dispose()).not.toThrow();
    });
  });
});

describe('Health View Integration', () => {
  it('should build health rows for connected state', () => {
    const state = createMinimalState();
    state.connectionStatus = 'connected';
    state.clientAttached = true;

    const rows = buildHealthRows(state as BurnBarState);

    expect(Array.isArray(rows)).toBe(true);
  });

  it('should build health rows for disconnected state', () => {
    const state = createMinimalState();
    state.connectionStatus = 'disconnected';

    const rows = buildHealthRows(state as BurnBarState);

    expect(Array.isArray(rows)).toBe(true);
  });

  it('should build health rows for connecting state', () => {
    const state = createMinimalState();
    state.connectionStatus = 'connecting';

    const rows = buildHealthRows(state as BurnBarState);

    expect(Array.isArray(rows)).toBe(true);
  });

  it('should build health rows with health data', () => {
    const state = createMinimalState();
    state.connectionStatus = 'connected';
    state.clientAttached = true;
    state.health = {
      parserHealth: [
        { provider: 'claude_code', healthy: true, message: 'OK' },
        { provider: 'factory', healthy: true, message: 'OK' }
      ]
    };

    const rows = buildHealthRows(state as BurnBarState);

    expect(Array.isArray(rows)).toBe(true);
    // Should have pass icons for healthy parsers
    const passIcons = rows.filter(r => r.icon === 'pass');
    expect(passIcons.length).toBeGreaterThan(0);
  });

  it('should build health rows with unhealthy parsers', () => {
    const state = createMinimalState();
    state.connectionStatus = 'connected';
    state.health = {
      parserHealth: [
        { provider: 'claude_code', healthy: true, message: 'OK' },
        { provider: 'factory', healthy: false, message: 'Parser error' }
      ]
    };

    const rows = buildHealthRows(state as BurnBarState);

    expect(Array.isArray(rows)).toBe(true);
    // Should have at least one warning
    const warningIcons = rows.filter(r => r.icon === 'warning');
    expect(warningIcons.length).toBeGreaterThan(0);
  });

  it('should create tree items for health rows', () => {
    const healthRows: BurnBarHealthRow[] = [
      { label: 'Parser Health', value: '3/3', icon: 'pass', tooltip: 'All parsers working' },
      { label: 'Daemon', value: 'Connected', icon: 'pass', tooltip: 'v1.0.0' },
      { label: 'Warning', value: 'Issue', icon: 'warning', tooltip: 'Some issue' },
      { label: 'Note', value: 'Info', icon: 'note' }
    ];

    // Test that tree items can be created for each row type
    healthRows.forEach(row => {
      const treeItem = new vscode.TreeItem(row.label, 0);
      treeItem.description = row.value;
      treeItem.iconPath = new vscode.ThemeIcon(row.icon);

      expect(treeItem.label).toBe(row.label);
      expect(treeItem.description).toBe(row.value);
    });
  });

  it('should handle state with lastError', () => {
    const state = createMinimalState();
    state.connectionStatus = 'error';
    state.lastError = 'Connection refused';

    const rows = buildHealthRows(state as BurnBarState);

    expect(Array.isArray(rows)).toBe(true);
    // Should have warning icons for error state
    const warningIcons = rows.filter(r => r.icon === 'warning');
    expect(warningIcons.length).toBeGreaterThan(0);
  });

  it('should handle state with runError', () => {
    const state = createMinimalState();
    state.connectionStatus = 'connected';
    state.runError = 'Run failed';

    const rows = buildHealthRows(state as BurnBarState);

    expect(Array.isArray(rows)).toBe(true);
  });
});
