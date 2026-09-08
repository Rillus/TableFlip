import Foundation

public final class RecentsStore {
    public struct Item: Equatable {
        public var kind: Kind
        public var displayName: String
        public var path: String
        public var isAvailable: Bool

        public enum Kind: String, Codable, Equatable {
            case sqliteFile
            case connection
        }
    }

    public enum Entry: Equatable {
        case sqliteFile(path: String)
        case connection(name: String, engine: EngineKind)
    }

    private let fileURL: URL
    private var entries: [Stored] = []

    private struct Stored: Codable, Equatable {
        var kind: Item.Kind
        var path: String
        var displayName: String
        var engine: String?
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        entries = Self.load(from: fileURL)
    }

    public var items: [Item] {
        entries.map { stored in
            Item(
                kind: stored.kind,
                displayName: stored.displayName,
                path: stored.path,
                isAvailable: stored.kind == .sqliteFile ? FileManager.default.fileExists(atPath: stored.path) : true
            )
        }
    }

    public func remember(_ entry: Entry) {
        let stored: Stored
        switch entry {
        case .sqliteFile(let path):
            stored = Stored(
                kind: .sqliteFile,
                path: path,
                displayName: URL(fileURLWithPath: path).lastPathComponent,
                engine: "sqlite"
            )
        case .connection(let name, let engine):
            stored = Stored(kind: .connection, path: name, displayName: name, engine: String(describing: engine))
        }
        entries.removeAll { $0.path == stored.path && $0.kind == stored.kind }
        entries.insert(stored, at: 0)
        if entries.count > 20 {
            entries = Array(entries.prefix(20))
        }
        persist()
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Recents are convenience only; never fail a database open.
        }
    }

    private static func load(from url: URL) -> [Stored] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Stored].self, from: data)
        else {
            return []
        }
        return decoded
    }
}
