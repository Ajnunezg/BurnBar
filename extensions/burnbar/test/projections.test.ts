import { describe, it, expect } from 'vitest';
import type {
  BurnBarState,
  BurnBarRunProjection,
  BurnBarCatalog,
  BurnBarRunStateSnapshot,
  BurnBarUsageEvent,
  BurnBarWorkspaceCapabilities,
  BurnBarRunPhase
} from '../src/types';
import {
  projectRuns,
  buildHealthRows,
  buildRunDetailRows,
  type BurnBarHealthRow,
  type BurnBarRunDetailRow
} from '../src/state/projections';

// Helper to create a minimal state for testing
function createMockState(overrides: Partial<BurnBarState> = {}): BurnBarState {
  return {
    connectionStatus: 'connected',
    clientAttached: true,
    health: {
      daemonVersion: '1.0.0',
      protocolVersion: '1.0.0',
      socketPath: '/tmp/burnbar.sock',
      uptimeSeconds: 3600
    },
    catalog: {
      providers: [],
      models: []
    },
    daemonRuns: [],
    pendingToolCalls: [],
    recentUsage: [],
    lastError: undefined,
    runError: undefined,
    workspace: undefined,
    workspaceError: undefined,
    runs: [],
    selectedRunId: undefined,
    selectedRunDetail: undefined,
    ...overrides
  } as BurnBarState;
}

// Helper to create a mock run
function createMockRun(overrides: Partial<BurnBarRunStateSnapshot> = {}): BurnBarRunStateSnapshot {
  return {
    runID: 'run-123',
    clientID: 'client-1',
    sessionID: 'session-1',
    modelID: 'claude-opus-4',
    phase: 'completed' as BurnBarRunPhase,
    updatedAt: '2024-01-15T12:00:00Z',
    errorMessage: undefined,
    ...overrides
  };
}

// Helper to create a mock catalog
function createMockCatalog(): BurnBarCatalog {
  return {
    providers: [
      {
        id: 'claude-code',
        displayName: 'Claude Code',
        models: [
          { id: 'claude-opus-4', displayName: 'Claude Opus 4', visibility: 'public' as const },
          { id: 'claude-sonnet-4', displayName: 'Claude Sonnet 4', visibility: 'public' as const }
        ]
      }
    ],
    models: []
  };
}

describe('projectRuns', () => {
  it('should return repairing state when connection is repairing', () => {
    const state = createMockState({ connectionStatus: 'repairing' });
    const result = projectRuns(state);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('repairing-daemon');
    expect(result[0].phase).toBe('planning');
    expect(result[0].source).toBe('projected');
  });

  it('should return daemon unavailable when not connected', () => {
    const state = createMockState({ connectionStatus: 'disconnected' });
    const result = projectRuns(state);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('daemon-unavailable');
    expect(result[0].phase).toBe('failed');
  });

  it('should return daemon unavailable when health is missing', () => {
    const state = createMockState({ health: undefined });
    const result = projectRuns(state);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('daemon-unavailable');
  });

  it('should return client session unavailable when not attached', () => {
    const state = createMockState({ clientAttached: false });
    const result = projectRuns(state);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('client-session-unavailable');
    expect(result[0].phase).toBe('failed');
  });

  it('should return run error state when runError is set', () => {
    const state = createMockState({ runError: 'Run state error' });
    const result = projectRuns(state);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('run-state-unavailable');
    expect(result[0].note).toContain('Run state error');
  });

  it('should return empty run list when no runs', () => {
    const state = createMockState();
    const result = projectRuns(state);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('empty-run-list');
    expect(result[0].phase).toBe('idle');
  });

  it('should project daemon runs when available', () => {
    const runs: BurnBarRunStateSnapshot[] = [
      createMockRun({ runID: 'run-1', phase: 'completed' }),
      createMockRun({ runID: 'run-2', phase: 'running' })
    ];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result).toHaveLength(2);
    expect(result[0].id).toBe('run-1');
    expect(result[0].source).toBe('daemon');
    expect(result[1].id).toBe('run-2');
  });

  it('should include error message in failed run', () => {
    const runs = [
      createMockRun({ runID: 'run-1', phase: 'failed', errorMessage: 'Test error' })
    ];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result[0].note).toBe('Test error');
  });

  it('should handle awaiting_approval phase', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'awaiting_approval' })];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result[0].note).toBe('Awaiting approval');
  });

  it('should handle untrusted workspace with awaiting_approval', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'awaiting_approval' })];
    const workspace: BurnBarWorkspaceCapabilities = {
      hasWorkspace: true,
      untrustedWorkspace: true,
      virtualWorkspace: false,
      remoteWorkspace: false,
      localWorkspace: true,
      readonlyWorkspace: false,
      workspaceHost: 'cursor',
      availableTools: ['read_file', 'search_workspace'],
      gatedTools: []
    };
    const state = createMockState({ daemonRuns: runs, workspace });
    const result = projectRuns(state);

    expect(result[0].note).toBe('Awaiting trust');
  });

  it('should handle completed run with usage', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'completed' })];
    const usage: BurnBarUsageEvent[] = [{
      runID: 'run-1',
      providerID: 'claude-code',
      inputTokens: 1000,
      outputTokens: 500,
      cost: 0.05,
      timestamp: new Date()
    }];
    const catalog = createMockCatalog();
    const state = createMockState({ daemonRuns: runs, recentUsage: usage, catalog });
    const result = projectRuns(state);

    expect(result[0].note).toContain('1500 billed tokens');
  });

  it('should handle idle phase', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'idle' })];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result[0].note).toContain('queued and waiting');
  });

  it('should handle planning phase', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'planning' })];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result[0].note).toContain('planning');
  });

  it('should handle executing_tool phase with pending tool', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'executing_tool' })];
    const pendingToolCalls: BurnBarState['pendingToolCalls'] = [{
      runID: 'run-1',
      tool: 'read_file',
      status: 'pending',
      requestedAt: new Date().toISOString()
    }];
    const state = createMockState({ daemonRuns: runs, pendingToolCalls });
    const result = projectRuns(state);

    expect(result[0].note).toContain('Reading file');
  });

  it('should handle executing_tool phase without pending tool', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'executing_tool' })];
    const state = createMockState({ daemonRuns: runs, pendingToolCalls: [] });
    const result = projectRuns(state);

    expect(result[0].note).toContain('executing a workspace tool');
  });

  it('should handle waiting_on_companion phase', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'waiting_on_companion' })];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result[0].note).toContain('waiting for the workspace companion');
  });

  it('should handle model_streaming phase', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'model_streaming' })];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result[0].note).toContain('streaming model output');
  });

  it('should handle cancelled phase', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'cancelled' })];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result[0].note).toContain('cancelled');
  });

  it('should include provider info from catalog', () => {
    const runs = [createMockRun({ runID: 'run-1', modelID: 'claude-opus-4' })];
    const catalog = createMockCatalog();
    const state = createMockState({ daemonRuns: runs, catalog });
    const result = projectRuns(state);

    expect(result[0].providerId).toBe('claude-code');
    expect(result[0].providerName).toBe('Claude Code');
  });

  it('should include provider info from usage', () => {
    const runs = [createMockRun({ runID: 'run-1' })];
    const usage: BurnBarUsageEvent[] = [{
      runID: 'run-1',
      providerID: 'claude-code',
      inputTokens: 100,
      outputTokens: 50,
      cost: 0.01,
      timestamp: new Date()
    }];
    const state = createMockState({ daemonRuns: runs, recentUsage: usage });
    const result = projectRuns(state);

    expect(result[0].providerId).toBe('claude-code');
  });
});

describe('buildHealthRows', () => {
  it('should return health rows for connected state', () => {
    const state = createMockState({
      connectionStatus: 'connected',
      clientAttached: true
    });
    const rows = buildHealthRows(state);

    expect(rows.some(r => r.id === 'status')).toBe(true);
    expect(rows.some(r => r.id === 'session')).toBe(true);
    expect(rows.some(r => r.id === 'daemon')).toBe(true);
  });

  it('should show correct status for disconnected', () => {
    const state = createMockState({ connectionStatus: 'disconnected' });
    const rows = buildHealthRows(state);

    const statusRow = rows.find(r => r.id === 'status');
    expect(statusRow?.value).toBe('Disconnected');
    expect(statusRow?.icon).toBe('warning');
  });

  it('should show correct status for connecting', () => {
    const state = createMockState({ connectionStatus: 'connecting' });
    const rows = buildHealthRows(state);

    const statusRow = rows.find(r => r.id === 'status');
    expect(statusRow?.value).toBe('Connecting');
  });

  it('should show correct status for repairing', () => {
    const state = createMockState({ connectionStatus: 'repairing' });
    const rows = buildHealthRows(state);

    const statusRow = rows.find(r => r.id === 'status');
    expect(statusRow?.value).toBe('Repairing');
    expect(statusRow?.icon).toBe('pulse');
  });

  it('should show session not attached warning', () => {
    const state = createMockState({ clientAttached: false });
    const rows = buildHealthRows(state);

    const sessionRow = rows.find(r => r.id === 'session');
    expect(sessionRow?.value).toBe('Not attached');
    expect(sessionRow?.icon).toBe('warning');
  });

  it('should show daemon version', () => {
    const state = createMockState();
    const rows = buildHealthRows(state);

    const daemonRow = rows.find(r => r.id === 'daemon');
    expect(daemonRow?.value).toBe('1.0.0');
  });

  it('should show protocol version', () => {
    const state = createMockState();
    const rows = buildHealthRows(state);

    const protocolRow = rows.find(r => r.id === 'protocol');
    expect(protocolRow?.value).toBe('v1.0.0');
  });

  it('should show socket path', () => {
    const state = createMockState();
    const rows = buildHealthRows(state);

    const socketRow = rows.find(r => r.id === 'socket');
    expect(socketRow?.value).toBe('/tmp/burnbar.sock');
  });

  it('should show unavailable when health is missing', () => {
    const state = createMockState({ health: undefined });
    const rows = buildHealthRows(state);

    const socketRow = rows.find(r => r.id === 'socket');
    expect(socketRow?.value).toBe('Unavailable');
  });

  it('should include last error when present', () => {
    const state = createMockState({ lastError: 'Test error message' });
    const rows = buildHealthRows(state);

    expect(rows.some(r => r.id === 'last-error')).toBe(true);
    const errorRow = rows.find(r => r.id === 'last-error');
    expect(errorRow?.value).toBe('Test error message');
    expect(errorRow?.icon).toBe('warning');
  });

  it('should include run error when present', () => {
    const state = createMockState({ runError: 'Run failed' });
    const rows = buildHealthRows(state);

    const runErrorRow = rows.find(r => r.id === 'run-error');
    expect(runErrorRow?.value).toBe('Run failed');
  });

  it('should show catalog status with providers', () => {
    const catalog = createMockCatalog();
    const state = createMockState({ catalog });
    const rows = buildHealthRows(state);

    const catalogRow = rows.find(r => r.id === 'catalog');
    expect(catalogRow?.value).toContain('1 providers');
    expect(catalogRow?.value).toContain('2 visible models');
    expect(catalogRow?.icon).toBe('pass');
  });

  it('should show catalog waiting status when no providers', () => {
    const state = createMockState({ catalog: { providers: [], models: [] } });
    const rows = buildHealthRows(state);

    const catalogRow = rows.find(r => r.id === 'catalog');
    expect(catalogRow?.value).toBe('Connected, waiting for provider catalog');
    expect(catalogRow?.icon).toBe('pulse');
  });

  it('should show catalog unavailable when disconnected', () => {
    const state = createMockState({ connectionStatus: 'disconnected' });
    const rows = buildHealthRows(state);

    const catalogRow = rows.find(r => r.id === 'catalog');
    expect(catalogRow?.value).toBe('Unavailable');
    expect(catalogRow?.icon).toBe('warning');
  });

  it('should show run count', () => {
    const runs = [
      createMockRun({ runID: 'run-1' }),
      createMockRun({ runID: 'run-2' })
    ];
    const state = createMockState({ daemonRuns: runs });
    const rows = buildHealthRows(state);

    const runsRow = rows.find(r => r.id === 'runs');
    expect(runsRow?.value).toBe('2 tracked');
    expect(runsRow?.icon).toBe('pass');
  });

  it('should show zero runs note', () => {
    const state = createMockState();
    const rows = buildHealthRows(state);

    const runsRow = rows.find(r => r.id === 'runs');
    expect(runsRow?.value).toBe('0 tracked');
    expect(runsRow?.icon).toBe('note');
  });

  it('should show workspace mode', () => {
    const workspace: BurnBarWorkspaceCapabilities = {
      hasWorkspace: true,
      untrustedWorkspace: false,
      virtualWorkspace: false,
      remoteWorkspace: false,
      localWorkspace: true,
      readonlyWorkspace: false,
      workspaceHost: 'cursor',
      availableTools: ['read_file'],
      gatedTools: []
    };
    const state = createMockState({ workspace });
    const rows = buildHealthRows(state);

    const workspaceRow = rows.find(r => r.id === 'workspace-mode');
    expect(workspaceRow?.value).toContain('Local');
    expect(workspaceRow?.value).toContain('trusted');
    expect(workspaceRow?.value).toContain('writable');
  });

  it('should show gated tools warning', () => {
    const workspace: BurnBarWorkspaceCapabilities = {
      hasWorkspace: true,
      untrustedWorkspace: false,
      virtualWorkspace: false,
      remoteWorkspace: false,
      localWorkspace: true,
      readonlyWorkspace: false,
      workspaceHost: 'cursor',
      availableTools: ['read_file'],
      gatedTools: ['apply_patch', 'run_terminal']
    };
    const state = createMockState({ workspace });
    const rows = buildHealthRows(state);

    const workspaceRow = rows.find(r => r.id === 'workspace-mode');
    expect(workspaceRow?.icon).toBe('warning');
  });

  it('should show workspace explanation when present', () => {
    const workspace: BurnBarWorkspaceCapabilities = {
      hasWorkspace: true,
      untrustedWorkspace: true,
      virtualWorkspace: false,
      remoteWorkspace: false,
      localWorkspace: true,
      readonlyWorkspace: false,
      workspaceHost: 'cursor',
      availableTools: [],
      gatedTools: [],
      explanation: 'Workspace is restricted'
    };
    const state = createMockState({ workspace });
    const rows = buildHealthRows(state);

    const explanationRow = rows.find(r => r.id === 'workspace-explanation');
    expect(explanationRow?.value).toBe('Workspace is restricted');
  });

  it('should show next step when recommended', () => {
    const state = createMockState({
      catalog: { providers: [], models: [] }
    });
    const rows = buildHealthRows(state);

    const nextStepRow = rows.find(r => r.id === 'next-step');
    expect(nextStepRow).toBeDefined();
  });
});

describe('buildRunDetailRows', () => {
  it('should return empty row when no run selected', () => {
    const state = createMockState();
    const rows = buildRunDetailRows(state);

    expect(rows).toHaveLength(1);
    expect(rows[0].id).toBe('empty');
  });

  it('should show selected run details', () => {
    const run: BurnBarRunProjection = {
      id: 'run-123',
      title: 'Run 12345678',
      phase: 'completed',
      note: 'Test note',
      updatedAt: '2024-01-15T12:00:00Z',
      source: 'daemon'
    };
    const state = createMockState({
      runs: [run],
      selectedRunId: 'run-123'
    });
    const rows = buildRunDetailRows(state);

    expect(rows.some(r => r.id === 'title')).toBe(true);
    expect(rows.some(r => r.id === 'phase')).toBe(true);
  });

  it('should show provider and model info', () => {
    const run: BurnBarRunProjection = {
      id: 'run-123',
      title: 'Run 12345678',
      phase: 'completed',
      note: '',
      updatedAt: '2024-01-15T12:00:00Z',
      source: 'daemon',
      providerId: 'claude-code',
      providerName: 'Claude Code',
      modelId: 'claude-opus-4'
    };
    const state = createMockState({
      runs: [run],
      selectedRunId: 'run-123'
    });
    const rows = buildRunDetailRows(state);

    expect(rows.some(r => r.id === 'provider')).toBe(true);
    expect(rows.some(r => r.id === 'model')).toBe(true);
  });

  it('should show run snapshot details when available', () => {
    const run: BurnBarRunProjection = {
      id: 'run-123',
      title: 'Run 12345678',
      phase: 'completed',
      note: '',
      updatedAt: '2024-01-15T12:00:00Z',
      source: 'daemon'
    };
    const daemonRun = createMockRun({
      runID: 'run-123',
      clientID: 'client-abc',
      sessionID: 'session-xyz'
    });
    const state = createMockState({
      runs: [run],
      selectedRunId: 'run-123',
      daemonRuns: [daemonRun]
    });
    const rows = buildRunDetailRows(state);

    expect(rows.some(r => r.id === 'run-id')).toBe(true);
    expect(rows.some(r => r.id === 'client-id')).toBe(true);
    expect(rows.some(r => r.id === 'session-id')).toBe(true);
  });

  it('should show error message when present', () => {
    const run: BurnBarRunProjection = {
      id: 'run-123',
      title: 'Run 12345678',
      phase: 'failed',
      note: '',
      updatedAt: '2024-01-15T12:00:00Z',
      source: 'daemon'
    };
    const daemonRun = createMockRun({
      runID: 'run-123',
      errorMessage: 'Something went wrong'
    });
    const state = createMockState({
      runs: [run],
      selectedRunId: 'run-123',
      daemonRuns: [daemonRun]
    });
    const rows = buildRunDetailRows(state);

    const errorRow = rows.find(r => r.id === 'error');
    expect(errorRow?.value).toBe('Something went wrong');
  });

  it('should show usage info when available', () => {
    const run: BurnBarRunProjection = {
      id: 'run-123',
      title: 'Run 12345678',
      phase: 'completed',
      note: '',
      updatedAt: '2024-01-15T12:00:00Z',
      source: 'daemon'
    };
    const usage: BurnBarUsageEvent[] = [{
      runID: 'run-123',
      providerID: 'claude-code',
      inputTokens: 1000,
      outputTokens: 500,
      cost: 0.05,
      timestamp: new Date()
    }];
    const state = createMockState({
      runs: [run],
      selectedRunId: 'run-123',
      recentUsage: usage
    });
    const rows = buildRunDetailRows(state);

    expect(rows.some(r => r.id === 'usage')).toBe(true);
  });

  it('should show approval request when pending', () => {
    const run: BurnBarRunProjection = {
      id: 'run-123',
      title: 'Run 12345678',
      phase: 'awaiting_approval',
      note: 'Approval needed',
      updatedAt: '2024-01-15T12:00:00Z',
      source: 'daemon'
    };
    const detail = {
      run: createMockRun({ runID: 'run-123' }),
      approvalRequest: {
        tool: 'apply_patch',
        title: 'Review Changes',
        message: 'Please review the changes',
        requestedAt: '2024-01-15T12:00:00Z'
      }
    };
    const state = createMockState({
      runs: [run],
      selectedRunId: 'run-123',
      selectedRunDetail: detail as any
    });
    const rows = buildRunDetailRows(state);

    expect(rows.some(r => r.id === 'approval-tool')).toBe(true);
    expect(rows.some(r => r.id === 'approval-requested-at')).toBe(true);
  });
});

// Integration tests
describe('Projection Integration', () => {
  it('should handle complete health check flow', () => {
    const state = createMockState({
      connectionStatus: 'connected',
      clientAttached: true,
      catalog: createMockCatalog(),
      daemonRuns: [createMockRun({ runID: 'run-1', phase: 'completed' })]
    });

    const runs = projectRuns(state);
    const healthRows = buildHealthRows(state);

    expect(runs).toHaveLength(1);
    expect(healthRows.some(r => r.value.includes('Connected'))).toBe(true);
  });

  it('should handle disconnected state gracefully', () => {
    const state = createMockState({
      connectionStatus: 'disconnected',
      lastError: 'Connection refused'
    });

    const runs = projectRuns(state);
    const healthRows = buildHealthRows(state);

    expect(runs).toHaveLength(1);
    expect(runs[0].id).toBe('daemon-unavailable');
    expect(healthRows.some(r => r.id === 'last-error')).toBe(true);
  });

  it('should handle empty workspace state', () => {
    const state = createMockState();
    const rows = buildHealthRows(state);

    expect(rows.some(r => r.id === 'workspace-mode')).toBe(true);
    const workspaceRow = rows.find(r => r.id === 'workspace-mode');
    expect(workspaceRow?.value).toContain('Detecting workspace companion');
  });
});

// Edge case tests
describe('Projection Edge Cases', () => {
  it('should handle malformed phase gracefully', () => {
    const runs = [createMockRun({ runID: 'run-1', phase: 'completed' as any })];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    expect(result[0].phase).toBe('completed');
  });

  it('should handle very long run ID', () => {
    const longRunId = 'run-' + 'a'.repeat(100);
    const runs = [createMockRun({ runID: longRunId })];
    const state = createMockState({ daemonRuns: runs });
    const result = projectRuns(state);

    // Short ID should truncate
    expect(result[0].title).toContain('run-');
    expect(result[0].title.length).toBeLessThan(longRunId.length + 10);
  });

  it('should handle workspace with all gated tools', () => {
    const workspace: BurnBarWorkspaceCapabilities = {
      hasWorkspace: true,
      untrustedWorkspace: true,
      virtualWorkspace: true,
      remoteWorkspace: true,
      localWorkspace: false,
      readonlyWorkspace: true,
      workspaceHost: 'cursor',
      availableTools: [],
      gatedTools: ['apply_patch', 'run_terminal', 'read_file', 'search_workspace']
    };
    const state = createMockState({ workspace });
    const rows = buildHealthRows(state);

    const workspaceRow = rows.find(r => r.id === 'workspace-mode');
    expect(workspaceRow?.value).toContain('Remote');
    expect(workspaceRow?.value).toContain('restricted');
    expect(workspaceRow?.value).toContain('read-only');
    expect(workspaceRow?.value).toContain('virtual');
  });

  it('should handle workspace with all tools available', () => {
    const workspace: BurnBarWorkspaceCapabilities = {
      hasWorkspace: true,
      untrustedWorkspace: false,
      virtualWorkspace: false,
      remoteWorkspace: false,
      localWorkspace: true,
      readonlyWorkspace: false,
      workspaceHost: 'cursor',
      availableTools: ['read_file', 'search_workspace', 'apply_patch', 'run_terminal'],
      gatedTools: []
    };
    const state = createMockState({ workspace });
    const rows = buildHealthRows(state);

    const workspaceRow = rows.find(r => r.id === 'workspace-mode');
    expect(workspaceRow?.icon).toBe('pass');
  });
});
