import Foundation

extension UserDefaults {
    private static let anonymousUsageStatisticsEnabledKey = "ai.covetype.app.anonymousUsageStatisticsEnabled"
    private static let telemetryInstallationIDKey = "ai.covetype.app.telemetryInstallationID"
    private static let telemetryLastAttemptDateKey = "ai.covetype.app.telemetryLastAttemptDate"

    var anonymousUsageStatisticsEnabled: Bool {
        get {
            guard object(forKey: Self.anonymousUsageStatisticsEnabledKey) != nil else { return true }
            return bool(forKey: Self.anonymousUsageStatisticsEnabledKey)
        }
        set { set(newValue, forKey: Self.anonymousUsageStatisticsEnabledKey) }
    }

    var telemetryInstallationID: String {
        if let existing = string(forKey: Self.telemetryInstallationIDKey),
           UUID(uuidString: existing) != nil {
            return existing.lowercased()
        }
        let generated = UUID().uuidString.lowercased()
        set(generated, forKey: Self.telemetryInstallationIDKey)
        return generated
    }

    var telemetryLastAttemptDate: Date? {
        get { object(forKey: Self.telemetryLastAttemptDateKey) as? Date }
        set {
            if let newValue {
                set(newValue, forKey: Self.telemetryLastAttemptDateKey)
            } else {
                removeObject(forKey: Self.telemetryLastAttemptDateKey)
            }
        }
    }
}

struct AnonymousUsagePayload: Codable, Equatable {
    let schemaVersion: Int
    let installationID: String
    let appVersion: String
    let macOSVersion: String
    let architecture: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case installationID = "installation_id"
        case appVersion = "app_version"
        case macOSVersion = "macos_version"
        case architecture
    }
}

enum TelemetryPolicy {
    static let minimumAttemptInterval: TimeInterval = 24 * 60 * 60

    static func shouldAttempt(enabled: Bool, lastAttempt: Date?, now: Date) -> Bool {
        guard enabled else { return false }
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= minimumAttemptInterval
    }
}

actor TelemetryService {
    private static let endpointInfoKey = "CoveTypeTelemetryURL"
    private let defaults: UserDefaults
    private let session: URLSession
    private let now: @Sendable () -> Date

    init(
        defaults: UserDefaults = .standard,
        session: URLSession = TelemetryService.makeEphemeralSession(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.session = session
        self.now = now
    }

    @discardableResult
    func sendHeartbeatIfNeeded() async -> Bool {
        let currentDate = now()
        guard TelemetryPolicy.shouldAttempt(
            enabled: defaults.anonymousUsageStatisticsEnabled,
            lastAttempt: defaults.telemetryLastAttemptDate,
            now: currentDate
        ), let endpointURL = Self.configuredEndpointURL else {
            return false
        }

        // Record the attempt before networking. A failed request is not retried until
        // 24 hours have elapsed, so CoveType never creates a launch retry loop.
        defaults.telemetryLastAttemptDate = currentDate

        do {
            let payload = Self.currentPayload(defaults: defaults)
            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 8
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("CoveType/\(payload.appVersion)", forHTTPHeaderField: "User-Agent")
            request.httpBody = try JSONEncoder.sorted.encode(payload)

            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    static func currentPayload(defaults: UserDefaults = .standard) -> AnonymousUsagePayload {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let operatingSystem = ProcessInfo.processInfo.operatingSystemVersion
        return AnonymousUsagePayload(
            schemaVersion: 1,
            installationID: defaults.telemetryInstallationID,
            appVersion: version,
            macOSVersion: "\(operatingSystem.majorVersion).\(operatingSystem.minorVersion)",
            architecture: architecture
        )
    }

    static var configuredEndpointURL: URL? {
        let environmentValue = ProcessInfo.processInfo.environment["COVETYPE_TELEMETRY_URL"]
        let bundledValue = Bundle.main.object(forInfoDictionaryKey: endpointInfoKey) as? String
        guard let rawValue = [environmentValue, bundledValue]
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }),
              let url = URL(string: rawValue),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url
    }

    static func runSelfTest() -> Bool {
        let suiteName = "ai.covetype.app.telemetry-self-test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return false }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        guard defaults.anonymousUsageStatisticsEnabled else { return false }
        let firstID = defaults.telemetryInstallationID
        guard UUID(uuidString: firstID) != nil,
              defaults.telemetryInstallationID == firstID else { return false }
        guard TelemetryPolicy.shouldAttempt(enabled: true, lastAttempt: nil, now: now) else { return false }
        guard TelemetryPolicy.shouldAttempt(
            enabled: true,
            lastAttempt: now.addingTimeInterval(-(TelemetryPolicy.minimumAttemptInterval - 1)),
            now: now
        ) == false else { return false }
        guard TelemetryPolicy.shouldAttempt(
            enabled: true,
            lastAttempt: now.addingTimeInterval(-TelemetryPolicy.minimumAttemptInterval),
            now: now
        ) else { return false }
        guard TelemetryPolicy.shouldAttempt(enabled: false, lastAttempt: nil, now: now) == false else { return false }
        guard configuredEndpointURL?.scheme == "https" else { return false }

        let payload = currentPayload(defaults: defaults)
        guard payload.schemaVersion == 1,
              payload.installationID == firstID,
              payload.macOSVersion.isEmpty == false,
              ["arm64", "x86_64", "unknown"].contains(payload.architecture) else { return false }
        return true
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
