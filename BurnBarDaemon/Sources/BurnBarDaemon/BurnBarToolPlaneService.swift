import BurnBarCore
import Foundation
import LocalAuthentication
import Security

#if os(macOS)
private func withToolPlaneKeychainInteractionDisabled<T>(_ operation: () throws -> T) rethrows -> T {
    var previousAllowed = DarwinBoolean(true)
    let readStatus = SecKeychainGetUserInteractionAllowed(&previousAllowed)
    let disableStatus = SecKeychainSetUserInteractionAllowed(false)
    defer {
        if disableStatus == errSecSuccess {
            if readStatus == errSecSuccess {
                _ = SecKeychainSetUserInteractionAllowed(previousAllowed.boolValue)
            } else {
                _ = SecKeychainSetUserInteractionAllowed(true)
            }
        }
    }
    return try operation()
}
#else
private func withToolPlaneKeychainInteractionDisabled<T>(_ operation: () throws -> T) rethrows -> T {
    try operation()
}
#endif

public protocol BurnBarConnectorSecretStoring: Sendable {
    func secret(for connector: BurnBarConnectorKind) async throws -> String?
    func setSecret(_ secret: String?, for connector: BurnBarConnectorKind) async throws
}

public actor BurnBarInMemoryConnectorSecretStore: BurnBarConnectorSecretStoring {
    private var secrets: [BurnBarConnectorKind: String]

    public init(secrets: [BurnBarConnectorKind: String] = [:]) {
        self.secrets = secrets
    }

    public func secret(for connector: BurnBarConnectorKind) async throws -> String? {
        secrets[connector]
    }

    public func setSecret(_ secret: String?, for connector: BurnBarConnectorKind) async throws {
        let normalized = secret?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized, normalized.isEmpty == false {
            secrets[connector] = normalized
        } else {
            secrets.removeValue(forKey: connector)
        }
    }
}

public actor BurnBarConnectorKeychainSecretStore: BurnBarConnectorSecretStoring {
    private let service: String

    public init(service: String = "com.burnbar.connector-plane") {
        self.service = service
    }

    public func secret(for connector: BurnBarConnectorKind) async throws -> String? {
        let context = LAContext()
        context.interactionNotAllowed = true
        let account = "connector.\(connector.rawValue).credential"
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        if #unavailable(macOS 11.0) {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        }
        var item: CFTypeRef?
        let status = withToolPlaneKeychainInteractionDisabled {
            SecItemCopyMatching(query as CFDictionary, &item)
        }
        if status == errSecItemNotFound
            || status == errSecInteractionNotAllowed
            || status == errSecUserCanceled
            || status == errSecAuthFailed {
            return nil
        }
        guard status == errSecSuccess,
              let data = item as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return String(data: data, encoding: .utf8)
    }

    public func setSecret(_ secret: String?, for connector: BurnBarConnectorKind) async throws {
        let account = "connector.\(connector.rawValue).credential"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let secret, secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let data = Data(secret.utf8)
            let attributes = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus == errSecItemNotFound {
                var createQuery = query
                createQuery[kSecValueData as String] = data
                let addStatus = SecItemAdd(createQuery as CFDictionary, nil)
                guard addStatus == errSecSuccess else {
                    throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
                }
            } else if updateStatus != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
            }
        } else {
            let deleteStatus = SecItemDelete(query as CFDictionary)
            guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(deleteStatus))
            }
        }
    }
}

public typealias BurnBarConnectorTransport = @Sendable (_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
public typealias BurnBarBrowserFetcher = @Sendable (_ url: URL) async throws -> (Data, HTTPURLResponse)
public typealias BurnBarBrowserOpener = @Sendable (_ url: URL) throws -> Void
public typealias BurnBarExecutableLocator = @Sendable (_ executableName: String) -> String?

private struct BurnBarStoredConnectorConfig: Codable, Hashable {
    let kind: BurnBarConnectorKind
    var isEnabled: Bool
    var baseURL: String
    var authKind: BurnBarConnectorAuthKind
    var metadata: [String: BurnBarJSONValue]
}

private struct BurnBarStoredConnectorValidation: Codable, Hashable {
    var status: BurnBarConnectorHealthStatus
    var checkedAt: Date
    var detail: String?
}

private struct BurnBarStoredConnectorPlaneFile: Codable, Hashable {
    var updatedAt: Date
    var configs: [String: BurnBarStoredConnectorConfig]
    var validations: [String: BurnBarStoredConnectorValidation]
}

private struct BurnBarStoredBrowserToolingFile: Codable, Hashable {
    var updatedAt: Date
    var preferredEngine: BurnBarBrowserEngineKind
    var allowExternalNavigation: Bool
    var engineEnabledState: [String: Bool]
}

public actor BurnBarConnectorPlaneService {
    private let fileURL: URL
    private let secretStore: any BurnBarConnectorSecretStoring
    private let transport: BurnBarConnectorTransport
    private let logger: BurnBarDaemonLogger
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var cachedState: BurnBarStoredConnectorPlaneFile?

    public init(
        fileURL: URL = BurnBarDaemonPaths.defaultConnectorPlaneURL,
        secretStore: any BurnBarConnectorSecretStoring = BurnBarConnectorKeychainSecretStore(),
        transport: BurnBarConnectorTransport? = nil,
        logger: BurnBarDaemonLogger = BurnBarDaemonLogger(category: "connector-plane")
    ) {
        self.fileURL = fileURL
        self.secretStore = secretStore
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return (data, httpResponse)
        }
        self.logger = logger
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func snapshot() async throws -> BurnBarConnectorPlaneSnapshot {
        let state = try loadStateIfNeeded()
        var connectors: [BurnBarConnectorConfigSnapshot] = []
        connectors.reserveCapacity(BurnBarConnectorKind.allCases.count)

        for kind in BurnBarConnectorKind.allCases {
            let config = state.configs[kind.rawValue] ?? Self.defaultConfig(for: kind)
            let validation = state.validations[kind.rawValue]
            let secret = try await secretStore.secret(for: kind)
            connectors.append(
                Self.snapshot(
                    for: config,
                    secret: secret,
                    validation: validation
                )
            )
        }

        return BurnBarConnectorPlaneSnapshot(
            updatedAt: state.updatedAt,
            connectors: connectors.sorted { $0.displayName < $1.displayName }
        )
    }

    public func updateConfig(_ request: BurnBarConnectorConfigUpdateRequest) async throws -> BurnBarConnectorPlaneSnapshot {
        var state = try loadStateIfNeeded()
        let trimmedBaseURL = request.config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        state.configs[request.config.kind.rawValue] = BurnBarStoredConnectorConfig(
            kind: request.config.kind,
            isEnabled: request.config.isEnabled,
            baseURL: trimmedBaseURL,
            authKind: request.config.authKind,
            metadata: request.config.metadata
        )
        if request.replaceSecret {
            try await secretStore.setSecret(request.secret, for: request.config.kind)
        }
        state.validations[request.config.kind.rawValue] = nil
        state.updatedAt = Date()
        try persist(state)
        return try await snapshot()
    }

    public func performAction(_ request: BurnBarConnectorActionRequest) async throws -> BurnBarConnectorActionResponse {
        var state = try loadStateIfNeeded()
        let config = state.configs[request.kind.rawValue] ?? Self.defaultConfig(for: request.kind)
        let secret = try await secretStore.secret(for: request.kind)
        let now = Date()

        guard config.isEnabled else {
            let response = BurnBarConnectorActionResponse(
                kind: request.kind,
                action: request.action,
                ok: false,
                summary: "\(Self.displayName(for: request.kind)) is disabled.",
                detail: "Enable the connector before testing it.",
                recordedAt: now
            )
            state.validations[request.kind.rawValue] = BurnBarStoredConnectorValidation(
                status: .disabled,
                checkedAt: now,
                detail: response.detail
            )
            try persist(state)
            return response
        }

        guard let secret, secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            let response = BurnBarConnectorActionResponse(
                kind: request.kind,
                action: request.action,
                ok: false,
                summary: "\(Self.displayName(for: request.kind)) is missing credentials.",
                detail: "Save a token or access credential in BurnBar Settings first.",
                recordedAt: now
            )
            state.validations[request.kind.rawValue] = BurnBarStoredConnectorValidation(
                status: .missingSecret,
                checkedAt: now,
                detail: response.detail
            )
            try persist(state)
            return response
        }

        do {
            let response = try await performRemoteAction(
                request,
                config: config,
                secret: secret,
                recordedAt: now
            )
            state.validations[request.kind.rawValue] = BurnBarStoredConnectorValidation(
                status: .healthy,
                checkedAt: now,
                detail: response.summary
            )
            state.updatedAt = now
            try persist(state)
            return response
        } catch {
            let response = BurnBarConnectorActionResponse(
                kind: request.kind,
                action: request.action,
                ok: false,
                summary: "\(Self.displayName(for: request.kind)) request failed.",
                detail: error.localizedDescription,
                recordedAt: now
            )
            state.validations[request.kind.rawValue] = BurnBarStoredConnectorValidation(
                status: .degraded,
                checkedAt: now,
                detail: error.localizedDescription
            )
            state.updatedAt = now
            try persist(state)
            return response
        }
    }

    private func performRemoteAction(
        _ request: BurnBarConnectorActionRequest,
        config: BurnBarStoredConnectorConfig,
        secret: String,
        recordedAt: Date
    ) async throws -> BurnBarConnectorActionResponse {
        let urlRequest = try makeRequest(for: request.kind, config: config, secret: secret)
        let (data, response) = try await transport(urlRequest)
        guard (200 ..< 300).contains(response.statusCode) else {
            throw NSError(
                domain: "BurnBarConnectorPlaneService",
                code: response.statusCode,
                userInfo: [NSLocalizedDescriptionKey: Self.httpErrorDetail(data: data, statusCode: response.statusCode)]
            )
        }

        let jsonObject = try Self.jsonObject(from: data)
        let payload = Self.jsonValue(from: jsonObject)
        let (summary, detail) = Self.responseSummary(for: request.kind, payload: jsonObject)

        return BurnBarConnectorActionResponse(
            kind: request.kind,
            action: request.action,
            ok: true,
            summary: summary,
            detail: detail,
            payload: payload,
            recordedAt: recordedAt
        )
    }

    private func makeRequest(
        for kind: BurnBarConnectorKind,
        config: BurnBarStoredConnectorConfig,
        secret: String
    ) throws -> URLRequest {
        let trimmedBaseURL = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmedBaseURL), trimmedBaseURL.isEmpty == false else {
            throw NSError(
                domain: "BurnBarConnectorPlaneService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Connector base URL is invalid."]
            )
        }

        switch kind {
        case .github:
            var request = URLRequest(url: baseURL.appendingPathComponent("user"))
            request.httpMethod = "GET"
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            return request
        case .slack:
            var request = URLRequest(url: baseURL.appendingPathComponent("auth.test"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            return request
        case .linear:
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(secret, forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(["query": "{ viewer { id name email } }"])
            return request
        case .posthog:
            var components = URLComponents(url: baseURL.appendingPathComponent("projects"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "limit", value: "1")]
            guard let url = components?.url else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            return request
        case .sentry:
            var request = URLRequest(url: baseURL.appendingPathComponent("organizations"))
            request.httpMethod = "GET"
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            return request
        case .gmail:
            var request = URLRequest(url: baseURL.appendingPathComponent("users/me/profile"))
            request.httpMethod = "GET"
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            return request
        }
    }

    private func loadStateIfNeeded() throws -> BurnBarStoredConnectorPlaneFile {
        if let cachedState {
            return cachedState
        }

        let defaultState = Self.defaultState()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedState = defaultState
            return defaultState
        }

        let data = try Data(contentsOf: fileURL)
        let decoded = try decoder.decode(BurnBarStoredConnectorPlaneFile.self, from: data)
        cachedState = decoded
        return decoded
    }

    private func persist(_ state: BurnBarStoredConnectorPlaneFile) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
        cachedState = state
    }

    private static func defaultState() -> BurnBarStoredConnectorPlaneFile {
        BurnBarStoredConnectorPlaneFile(
            updatedAt: Date(),
            configs: Dictionary(
                uniqueKeysWithValues: BurnBarConnectorKind.allCases.map { kind in
                    (kind.rawValue, defaultConfig(for: kind))
                }
            ),
            validations: [:]
        )
    }

    private static func defaultConfig(for kind: BurnBarConnectorKind) -> BurnBarStoredConnectorConfig {
        switch kind {
        case .github:
            return BurnBarStoredConnectorConfig(kind: kind, isEnabled: false, baseURL: "https://api.github.com", authKind: .bearerToken, metadata: [:])
        case .slack:
            return BurnBarStoredConnectorConfig(kind: kind, isEnabled: false, baseURL: "https://slack.com/api", authKind: .bearerToken, metadata: [:])
        case .linear:
            return BurnBarStoredConnectorConfig(kind: kind, isEnabled: false, baseURL: "https://api.linear.app/graphql", authKind: .bearerToken, metadata: [:])
        case .posthog:
            return BurnBarStoredConnectorConfig(kind: kind, isEnabled: false, baseURL: "https://app.posthog.com/api", authKind: .bearerToken, metadata: [:])
        case .sentry:
            return BurnBarStoredConnectorConfig(kind: kind, isEnabled: false, baseURL: "https://sentry.io/api/0", authKind: .bearerToken, metadata: [:])
        case .gmail:
            return BurnBarStoredConnectorConfig(kind: kind, isEnabled: false, baseURL: "https://gmail.googleapis.com/gmail/v1", authKind: .oauthAccessToken, metadata: [:])
        }
    }

    private static func snapshot(
        for config: BurnBarStoredConnectorConfig,
        secret: String?,
        validation: BurnBarStoredConnectorValidation?
    ) -> BurnBarConnectorConfigSnapshot {
        let secretConfigured = secret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let status: BurnBarConnectorHealthStatus
        if config.isEnabled == false {
            status = .disabled
        } else if !secretConfigured {
            status = .missingSecret
        } else {
            status = validation?.status ?? .configured
        }

        return BurnBarConnectorConfigSnapshot(
            kind: config.kind,
            displayName: displayName(for: config.kind),
            isEnabled: config.isEnabled,
            baseURL: config.baseURL,
            authKind: config.authKind,
            secretConfigured: secretConfigured,
            secretHint: secretConfigured ? Self.secretHint(for: secret) : nil,
            status: status,
            lastCheckedAt: validation?.checkedAt,
            statusDetail: validation?.detail,
            supportedActions: BurnBarConnectorActionKind.allCases,
            metadata: config.metadata
        )
    }

    private static func displayName(for kind: BurnBarConnectorKind) -> String {
        switch kind {
        case .github: return "GitHub"
        case .slack: return "Slack"
        case .linear: return "Linear"
        case .posthog: return "PostHog"
        case .sentry: return "Sentry"
        case .gmail: return "Gmail"
        }
    }

    private static func secretHint(for secret: String?) -> String? {
        guard let secret, secret.count >= 4 else { return nil }
        return "\(secret.prefix(2))…\(secret.suffix(2))"
    }

    private static func jsonObject(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    private static func jsonValue(from object: Any) -> BurnBarJSONValue {
        switch object {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        case let dictionary as [String: Any]:
            return .object(dictionary.mapValues(jsonValue(from:)))
        case let array as [Any]:
            return .array(array.map(jsonValue(from:)))
        default:
            return .null
        }
    }

    private static func responseSummary(
        for kind: BurnBarConnectorKind,
        payload: Any
    ) -> (String, String?) {
        let dictionary = payload as? [String: Any]
        switch kind {
        case .github:
            let login = dictionary?["login"] as? String ?? "unknown account"
            return ("Connected to GitHub as \(login).", dictionary?["html_url"] as? String)
        case .slack:
            let team = dictionary?["team"] as? String ?? "Slack workspace"
            let user = dictionary?["user"] as? String ?? "unknown user"
            return ("Connected to Slack workspace \(team).", "Authenticated as \(user).")
        case .linear:
            let viewer = ((dictionary?["data"] as? [String: Any])?["viewer"] as? [String: Any]) ?? [:]
            let name = viewer["name"] as? String ?? "Linear viewer"
            let email = viewer["email"] as? String
            return ("Connected to Linear as \(name).", email)
        case .posthog:
            let results = (dictionary?["results"] as? [[String: Any]]) ?? []
            let projectName = results.first?["name"] as? String ?? "PostHog project"
            return ("Connected to PostHog.", projectName)
        case .sentry:
            let organizations = (payload as? [[String: Any]]) ?? []
            let first = organizations.first
            let name = first?["name"] as? String ?? first?["slug"] as? String ?? "Sentry organization"
            return ("Connected to Sentry.", name)
        case .gmail:
            let email = dictionary?["emailAddress"] as? String ?? "Gmail profile"
            let messages = dictionary?["messagesTotal"] as? Int
            return ("Connected to Gmail as \(email).", messages.map { "\($0) total messages." })
        }
    }

    private static func httpErrorDetail(data: Data, statusCode: Int) -> String {
        if let string = String(data: data, encoding: .utf8),
           string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "HTTP \(statusCode): \(string)"
        }
        return "HTTP \(statusCode)"
    }
}

public actor BurnBarBrowserToolService {
    private let fileURL: URL
    private let fetcher: BurnBarBrowserFetcher
    private let opener: BurnBarBrowserOpener
    private let locateExecutable: BurnBarExecutableLocator
    private let logger: BurnBarDaemonLogger
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var cachedState: BurnBarStoredBrowserToolingFile?

    public init(
        fileURL: URL = BurnBarDaemonPaths.defaultBrowserToolingURL,
        fetcher: BurnBarBrowserFetcher? = nil,
        opener: BurnBarBrowserOpener? = nil,
        locateExecutable: BurnBarExecutableLocator? = nil,
        logger: BurnBarDaemonLogger = BurnBarDaemonLogger(category: "browser-tooling")
    ) {
        self.fileURL = fileURL
        self.fetcher = fetcher ?? { url in
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return (data, httpResponse)
        }
        self.opener = opener ?? { url in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [url.absoluteString]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw NSError(
                    domain: "BurnBarBrowserToolService",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to open URL in the system browser."]
                )
            }
        }
        self.locateExecutable = locateExecutable ?? { name in
            let candidates = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
            if let direct = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                return direct
            }
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [name]
            process.standardOutput = output
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                return path.isEmpty ? nil : path
            } catch {
                return nil
            }
        }
        self.logger = logger
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func snapshot() throws -> BurnBarBrowserToolingSnapshot {
        let state = try loadStateIfNeeded()
        let engines = BurnBarBrowserEngineKind.allCases.map { kind in
            let executablePath = executablePath(for: kind)
            return BurnBarBrowserEngineSnapshot(
                kind: kind,
                displayName: Self.displayName(for: kind),
                isEnabled: state.engineEnabledState[kind.rawValue] ?? Self.defaultEnabledState(for: kind),
                status: status(for: kind, executablePath: executablePath),
                executablePath: executablePath,
                detail: detail(for: kind, executablePath: executablePath),
                supportsFetch: kind == .urlSession,
                supportsExternalNavigation: kind == .systemBrowser
            )
        }

        return BurnBarBrowserToolingSnapshot(
            updatedAt: state.updatedAt,
            preferredEngine: state.preferredEngine,
            allowExternalNavigation: state.allowExternalNavigation,
            engines: engines
        )
    }

    public func update(_ request: BurnBarBrowserToolingUpdateRequest) throws -> BurnBarBrowserToolingSnapshot {
        var state = try loadStateIfNeeded()
        state.preferredEngine = request.preferredEngine
        state.allowExternalNavigation = request.allowExternalNavigation
        state.engineEnabledState = Dictionary(uniqueKeysWithValues: request.enginePreferences.map { ($0.kind.rawValue, $0.isEnabled) })
        state.updatedAt = Date()
        try persist(state)
        return try snapshot()
    }

    public func performAction(_ request: BurnBarBrowserActionRequest) async throws -> BurnBarBrowserActionResponse {
        let snapshot = try snapshot()
        let engine = request.preferredEngine ?? snapshot.preferredEngine
        guard let selectedEngine = snapshot.engines.first(where: { $0.kind == engine }) else {
            return BurnBarBrowserActionResponse(
                action: request.action,
                engine: engine,
                ok: false,
                summary: "Unknown browser engine.",
                detail: nil,
                recordedAt: Date()
            )
        }

        guard selectedEngine.isEnabled else {
            return BurnBarBrowserActionResponse(
                action: request.action,
                engine: engine,
                ok: false,
                summary: "\(selectedEngine.displayName) is disabled.",
                detail: "Enable the engine in BurnBar Settings before using it.",
                recordedAt: Date()
            )
        }

        switch request.action {
        case .openExternal:
            guard snapshot.allowExternalNavigation else {
                return BurnBarBrowserActionResponse(
                    action: request.action,
                    engine: engine,
                    ok: false,
                    summary: "External navigation is disabled.",
                    detail: "Enable external navigation in BurnBar Settings.",
                    recordedAt: Date()
                )
            }
            guard engine == .systemBrowser else {
                return BurnBarBrowserActionResponse(
                    action: request.action,
                    engine: engine,
                    ok: false,
                    summary: "Open External only supports the system browser today.",
                    detail: "Choose System Browser to launch URLs.",
                    recordedAt: Date()
                )
            }

            let url = try validatedURL(request.url)
            try opener(url)
            return BurnBarBrowserActionResponse(
                action: request.action,
                engine: engine,
                ok: true,
                summary: "Opened \(url.host ?? url.absoluteString) in the system browser.",
                recordedAt: Date()
            )
        case .fetchDocument, .extractLinks:
            guard engine == .urlSession else {
                return BurnBarBrowserActionResponse(
                    action: request.action,
                    engine: engine,
                    ok: false,
                    summary: "\(selectedEngine.displayName) is visible for setup/status only.",
                    detail: "Document fetch and link extraction currently run through the daemon fetcher.",
                    recordedAt: Date()
                )
            }

            let url = try validatedURL(request.url)
            let (data, response) = try await fetcher(url)
            guard (200 ..< 300).contains(response.statusCode) else {
                return BurnBarBrowserActionResponse(
                    action: request.action,
                    engine: engine,
                    ok: false,
                    summary: "Fetch failed.",
                    detail: "HTTP \(response.statusCode)",
                    recordedAt: Date()
                )
            }

            let html = String(decoding: data, as: UTF8.self)
            let title = Self.extractTitle(from: html)
            let stripped = Self.stripHTML(html)
            let links = Self.extractLinks(from: html, limit: request.maxLinks)
            switch request.action {
            case .fetchDocument:
                return BurnBarBrowserActionResponse(
                    action: request.action,
                    engine: engine,
                    ok: true,
                    summary: "Fetched \(title ?? url.host ?? url.absoluteString).",
                    detail: nil,
                    title: title,
                    document: stripped,
                    recordedAt: Date()
                )
            case .extractLinks:
                return BurnBarBrowserActionResponse(
                    action: request.action,
                    engine: engine,
                    ok: true,
                    summary: "Extracted \(links.count) link\(links.count == 1 ? "" : "s").",
                    title: title,
                    document: stripped.map { String($0.prefix(280)) },
                    links: links,
                    recordedAt: Date()
                )
            case .openExternal:
                fatalError("Handled above.")
            }
        }
    }

    private func loadStateIfNeeded() throws -> BurnBarStoredBrowserToolingFile {
        if let cachedState {
            return cachedState
        }

        let defaultState = Self.defaultState()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedState = defaultState
            return defaultState
        }

        let data = try Data(contentsOf: fileURL)
        let decoded = try decoder.decode(BurnBarStoredBrowserToolingFile.self, from: data)
        cachedState = decoded
        return decoded
    }

    private func persist(_ state: BurnBarStoredBrowserToolingFile) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
        cachedState = state
    }

    private func executablePath(for kind: BurnBarBrowserEngineKind) -> String? {
        switch kind {
        case .systemBrowser:
            return FileManager.default.isExecutableFile(atPath: "/usr/bin/open") ? "/usr/bin/open" : nil
        case .urlSession:
            return nil
        case .playwright:
            return locateExecutable("playwright")
        case .lightpanda:
            return locateExecutable("lightpanda")
        }
    }

    private func status(for kind: BurnBarBrowserEngineKind, executablePath: String?) -> BurnBarBrowserToolStatus {
        switch kind {
        case .urlSession:
            return .ready
        case .systemBrowser:
            return executablePath == nil ? .unavailable : .ready
        case .playwright, .lightpanda:
            return executablePath == nil ? .unavailable : .ready
        }
    }

    private func detail(for kind: BurnBarBrowserEngineKind, executablePath: String?) -> String {
        switch kind {
        case .urlSession:
            return "Daemon-side fetch plane for page text and links."
        case .systemBrowser:
            return executablePath == nil ? "System browser launcher is unavailable." : "Uses /usr/bin/open to launch URLs."
        case .playwright:
            return executablePath == nil ? "Install Playwright CLI to expose future browser automation." : "Detected for future browser automation."
        case .lightpanda:
            return executablePath == nil ? "Install Lightpanda to expose lightweight browser automation." : "Detected for future browser automation."
        }
    }

    private func validatedURL(_ rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), trimmed.isEmpty == false else {
            throw NSError(
                domain: "BurnBarBrowserToolService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Browser action URL is invalid."]
            )
        }
        return url
    }

    private static func defaultState() -> BurnBarStoredBrowserToolingFile {
        BurnBarStoredBrowserToolingFile(
            updatedAt: Date(),
            preferredEngine: .urlSession,
            allowExternalNavigation: true,
            engineEnabledState: Dictionary(uniqueKeysWithValues: BurnBarBrowserEngineKind.allCases.map { ($0.rawValue, defaultEnabledState(for: $0)) })
        )
    }

    private static func defaultEnabledState(for kind: BurnBarBrowserEngineKind) -> Bool {
        switch kind {
        case .systemBrowser, .urlSession:
            return true
        case .playwright, .lightpanda:
            return false
        }
    }

    private static func displayName(for kind: BurnBarBrowserEngineKind) -> String {
        switch kind {
        case .systemBrowser: return "System Browser"
        case .urlSession: return "Daemon Fetcher"
        case .playwright: return "Playwright"
        case .lightpanda: return "Lightpanda"
        }
    }

    private static func extractTitle(from html: String) -> String? {
        guard let range = html.range(
            of: "(?is)<title[^>]*>(.*?)</title>",
            options: .regularExpression
        ) else {
            return nil
        }
        let fragment = String(html[range])
        return fragment
            .replacingOccurrences(of: "(?is)</?title[^>]*>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripHTML(_ html: String) -> String? {
        let stripped = html
            .replacingOccurrences(of: "(?is)<script[^>]*>.*?</script>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<style[^>]*>.*?</style>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : String(stripped.prefix(4_000))
    }

    private static func extractLinks(from html: String, limit: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "(?is)href\\s*=\\s*[\"']([^\"']+)[\"']") else {
            return []
        }
        let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
        var links: [String] = []
        regex.enumerateMatches(in: html, options: [], range: nsrange) { match, _, stop in
            guard let match,
                  let range = Range(match.range(at: 1), in: html) else {
                return
            }
            links.append(String(html[range]))
            if links.count >= max(1, limit) {
                stop.pointee = true
            }
        }
        return links
    }
}
