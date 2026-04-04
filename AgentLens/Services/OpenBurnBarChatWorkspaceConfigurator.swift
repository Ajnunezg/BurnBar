import Foundation

/// Ensures each chat thread has an on-disk workspace and optional OpenBurnBar MCP hints so CLI-based
/// backends can attach the local index as a tool surface (see `tools/openburnbar-mcp/server.py`).
enum OpenBurnBarChatWorkspaceConfigurator {
    /// Writes `openburnbar-mcp.config.json` with `BURNBAR_DB_PATH` and a short README for manual MCP setup.
    static func ensureMCPHints(in workspaceURL: URL, databaseURL: URL) {
        try? FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)

        let dbPath = databaseURL.path
        let mcpPayload: [String: Any] = [
            "burnbar_mcp": [
                "description": "Read-only OpenBurnBar SQLite tools (search sessions, usage) via MCP.",
                "environment": [
                    "BURNBAR_DB_PATH": dbPath
                ],
                "setup": [
                    "Install deps: cd tools/openburnbar-mcp && ./setup.sh",
                    "Then register command: python3 tools/openburnbar-mcp/server.py with env BURNBAR_DB_PATH above in Codex or Claude MCP settings."
                ]
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: mcpPayload, options: [.prettyPrinted, .sortedKeys]) {
            let url = workspaceURL.appendingPathComponent("openburnbar-mcp.config.json", isDirectory: false)
            try? data.write(to: url, options: [.atomic])
        }

        let readme = """
        # OpenBurnBar chat workspace

        This folder is the default working directory for OpenBurnBar-managed CLI chat.

        - Database path for MCP: \(dbPath)
        - See `openburnbar-mcp.config.json` for environment variables to pass to the OpenBurnBar MCP server (`tools/openburnbar-mcp/server.py` in the OpenBurnBar repo).
        """
        let readmeURL = workspaceURL.appendingPathComponent("README-BURNBAR-CHAT.md", isDirectory: false)
        try? readme.data(using: .utf8)?.write(to: readmeURL, options: [.atomic])
    }
}
