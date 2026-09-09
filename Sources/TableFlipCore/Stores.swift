import Foundation

public protocol SecretStore: AnyObject {
    func setPassword(_ password: String?, for id: UUID)
    func password(for id: UUID) -> String?
}

public final class InMemorySecretStore: SecretStore {
    private var storage: [UUID: String] = [:]

    public init() {}

    public func setPassword(_ password: String?, for id: UUID) {
        storage[id] = password
    }

    public func password(for id: UUID) -> String? {
        storage[id]
    }
}

#if os(macOS)
import Security

public final class KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String = "com.tableflip.connections") {
        self.service = service
    }

    public func setPassword(_ password: String?, for id: UUID) {
        let account = id.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard let password, let data = password.data(using: .utf8) else { return }
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    public func password(for id: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
#endif

public final class ConnectionStore {
    private struct Record: Codable {
        var id: UUID
        var name: String
        var engine: String
        var host: String?
        var port: Int?
        var username: String?
        var database: String?
        var filePath: String?
        var ssl: Bool
    }

    private let fileURL: URL
    private let secrets: SecretStore
    private var records: [Record] = []

    public init(fileURL: URL, secrets: SecretStore) {
        self.fileURL = fileURL
        self.secrets = secrets
        records = Self.load(from: fileURL)
    }

    public var summaries: [(id: UUID, name: String, engine: EngineKind, host: String?)] {
        records.map { ($0.id, $0.name, engineKind($0.engine), $0.host) }
    }

    @discardableResult
    public func save(_ config: ConnectionConfig, name: String, id: UUID = UUID()) throws -> UUID {
        records.removeAll { $0.id == id }
        records.append(
            Record(
                id: id,
                name: name,
                engine: String(describing: config.engine),
                host: config.host,
                port: config.port,
                username: config.username,
                database: config.database,
                filePath: config.filePath,
                ssl: config.ssl
            )
        )
        secrets.setPassword(config.password, for: id)
        try persist()
        return id
    }

    public func load(_ id: UUID) throws -> ConnectionConfig {
        guard let record = records.first(where: { $0.id == id }) else {
            throw TableFlipError.engine("That connection is no longer saved.")
        }
        return ConnectionConfig(
            engine: engineKind(record.engine),
            host: record.host,
            port: record.port,
            username: record.username,
            password: secrets.password(for: id),
            database: record.database,
            filePath: record.filePath,
            ssl: record.ssl
        )
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [Record] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Record].self, from: data)) ?? []
    }

    private func engineKind(_ raw: String) -> EngineKind {
        switch raw {
        case "postgres": return .postgres
        case "mysql": return .mysql
        case "mariaDB": return .mariaDB
        default: return .sqlite
        }
    }
}

public final class PreferencesStore {
    private struct Payload: Codable {
        var pageSize: Int
        var confirmOnCommit: Bool
        var gridFontSize: Double
        var editorFontSize: Double
        var appearance: String
    }

    private let fileURL: URL
    public var pageSize: Int
    public var confirmOnCommit: Bool
    public var gridFontSize: Double
    public var editorFontSize: Double
    public var appearance: String

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            pageSize = payload.pageSize
            confirmOnCommit = payload.confirmOnCommit
            gridFontSize = payload.gridFontSize
            editorFontSize = payload.editorFontSize
            appearance = payload.appearance
        } else {
            pageSize = 100
            confirmOnCommit = true
            gridFontSize = 13
            editorFontSize = 13
            appearance = "system"
        }
    }

    public func save() {
        let payload = Payload(
            pageSize: pageSize,
            confirmOnCommit: confirmOnCommit,
            gridFontSize: gridFontSize,
            editorFontSize: editorFontSize,
            appearance: appearance
        )
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
