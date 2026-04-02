# Fix TypeScript `as unknown as` Casts

## Problem
The controller uses `as unknown as` casts to convert workspace RPC results to `BurnBarJSONValue`. This pattern bypasses TypeScript's type checking and can mask type errors.

## Solution
Create proper conversion utilities that explicitly convert workspace results to `BurnBarJSONValue`.

## Files to Create
- `extensions/burnbar/src/workspace/conversion.ts` - Conversion utilities

## Files to Modify
- `extensions/burnbar/src/state/controller.ts` - Use conversion utilities instead of casts

## Implementation

### conversion.ts
```typescript
import type { BurnBarJSONValue } from "../types";
import type {
  BurnBarReadFileResult,
  BurnBarSearchWorkspaceResult,
  BurnBarSearchBurnbarIndexResult,
  BurnBarApplyPatchResult,
  BurnBarRunTerminalResult
} from "./types";

export function readFileResultToJSON(result: BurnBarReadFileResult): BurnBarJSONValue {
  return { path: result.path, content: result.content };
}

export function searchWorkspaceResultToJSON(result: BurnBarSearchWorkspaceResult): BurnBarJSONValue {
  return {
    matches: result.matches.map(match => ({
      path: match.path,
      line: match.line,
      character: match.character,
      preview: match.preview
    }))
  };
}

export function searchBurnbarIndexResultToJSON(result: BurnBarSearchBurnbarIndexResult): BurnBarJSONValue {
  return {
    plan: result.plan,
    aggregateOccurrenceCount: result.aggregateOccurrenceCount ?? null,
    hits: result.hits.map(hit => ({
      chunkID: hit.chunkID,
      sourceKind: hit.sourceKind,
      sourceID: hit.sourceID,
      title: hit.title,
      snippet: hit.snippet,
      provider: hit.provider ?? null,
      projectName: hit.projectName ?? null
    })),
    degradedMessage: result.degradedMessage ?? null
  };
}

export function applyPatchResultToJSON(result: BurnBarApplyPatchResult): BurnBarJSONValue {
  return { applied: result.applied, changedFiles: result.changedFiles };
}

export function runTerminalResultToJSON(result: BurnBarRunTerminalResult): BurnBarJSONValue {
  return { terminalName: result.terminalName, cwd: result.cwd ?? null };
}
```

### controller.ts changes
Replace lines 659-721 with:
```typescript
import {
  readFileResultToJSON,
  searchWorkspaceResultToJSON,
  applyPatchResultToJSON,
  runTerminalResultToJSON
} from "../workspace/conversion";

// In invokeWorkspaceTool:
case "read_file": {
  const path = expectString(args.path, "read_file.path");
  if (!workspaceClient.readFile) {
    throw new Error("Workspace RPC client does not support read_file.");
  }
  const result = await workspaceClient.readFile({ path });
  return readFileResultToJSON(result);
}
case "search_workspace": {
  // ... same pattern
  return searchWorkspaceResultToJSON(result);
}
case "apply_patch": {
  // ... same pattern
  return applyPatchResultToJSON(result);
}
case "run_terminal": {
  // ... same pattern
  return runTerminalResultToJSON(result);
}
```

## Verification
1. TypeScript compiles without errors
2. All tests pass
3. No more `as unknown as` in controller.ts
