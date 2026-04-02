import Foundation

actor BurnBarLocalNotificationBridge {
    static let shared = BurnBarLocalNotificationBridge()

    func deliver(title: String, body: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            #"display notification "\#(escape(body))" with title "\#(escape(title))""#
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "BurnBarMissionControlTransport",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "osascript failed while posting a local notification."]
            )
        }
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

