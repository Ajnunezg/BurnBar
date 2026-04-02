# Fix TypeScript `as unknown as` Casts - Implementation

## Objective
Replace unsafe `as unknown as` casts in controller.ts with type-safe conversion utilities.

## Tasks

[x] Step 1: Create conversion.ts
[x] Step 2: Update controller.ts (add import)
[x] Step 3: Replace invokeWorkspaceTool method
[x] Step 4: Verify build and tests

---

## Verification Results

✅ `npm run build` - Passed
✅ `npm test` - All 290 tests passed

## Files Changed

| File | Change |
|------|--------|
| `src/workspace/conversion.ts` | **NEW** - 52 lines |
| `src/state/controller.ts` | Added import, replaced 4 casts |

Create file: `extensions/burnbar/src/workspace/conversion.ts`

```typescript
/**
 * Conversion utilities for workspace RPC results to BurnBarJSONValue.
 */

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

## Step 2: Update controller.ts

Add import near the top (around line 25):
```typescript
import {
  readFileResultToJSON,
  searchWorkspaceResultToJSON,
  applyPatchResultToJSON,
  runTerminalResultToJSON
} from "../workspace/conversion";
```

Replace `invokeWorkspaceTool` method (lines 659-721) with:
```typescript
private async invokeWorkspaceTool(toolCall: BurnBarToolCallSnapshot): Promise<BurnBarJSONValue> {
  const args = expectObject(toolCall.arguments, `tool call ${toolCall.callID} arguments`);
  const workspaceClient = this.dependencies.workspaceClient;

  switch (toolCall.tool) {
    case "read_file": {
      const path = expectString(args.path, "read_file.path");
      if (!workspaceClient.readFile) {
        throw new Error("Workspace RPC client does not support read_file.");
      }
      const result = await workspaceClient.readFile({ path });
      return readFileResultToJSON(result);
    }
    case "search_workspace": {
      const query = expectString(args.query, "search_workspace.query");
      if (!workspaceClient.searchWorkspace) {
        throw new Error("Workspace RPC client does not support search_workspace.");
      }
      const result = await workspaceClient.searchWorkspace({
        query,
        include: optionalString(args.include),
        exclude: optionalString(args.exclude),
        maxResults: optionalNumber(args.maxResults),
        maxFiles: optionalNumber(args.maxFiles),
        maxFileBytes: optionalNumber(args.maxFileBytes),
        caseSensitive: optionalBoolean(args.caseSensitive)
      });
      return searchWorkspaceResultToJSON(result);
    }
    case "apply_patch": {
      const changes = expectArray(args.changes, "apply_patch.changes");
      if (!workspaceClient.applyPatch) {
        throw new Error("Workspace RPC client does not support apply_patch.");
      }
      const result = await workspaceClient.applyPatch({
        changes: changes.map((change, index) => {
          const object = expectObject(change, `apply_patch.changes[${index}]`);
          return {
            path: expectString(object.path, `apply_patch.changes[${index}].path`),
            text: expectString(object.text, `apply_patch.changes[${index}].text`),
            range: object.range
              ? toRange(expectObject(object.range, `apply_patch.changes[${index}].range`))
              : undefined
          };
        })
      });
      return applyPatchResultToJSON(result);
    }
    case "run_terminal": {
      const command = expectString(args.command, "run_terminal.command");
      if (!workspaceClient.runTerminal) {
        throw new Error("Workspace RPC client does not support run_terminal.");
      }
      const result = await workspaceClient.runTerminal({
        command,
        cwd: optionalString(args.cwd),
        name: optionalString(args.name),
        preserveFocus: optionalBoolean(args.preserveFocus)
      });
      return runTerminalResultToJSON(result);
    }
  }
}
```

## Step 3: Verify

Run:
```bash
cd extensions/burnbar && npm run build && npm test
```

Expected: All tests pass, TypeScript compiles without errors.
