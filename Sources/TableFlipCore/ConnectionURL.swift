import Foundation

public enum ConnectionURLParser {
    public static func parse(_ string: String) throws -> ConnectionConfig {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased() else {
            throw TableFlipError.invalidConnectionURL
        }
        switch scheme {
        case "postgres", "postgresql":
            return ConnectionConfig(
                engine: .postgres,
                host: url.host,
                port: url.port ?? 5432,
                username: url.user,
                password: url.password,
                database: databaseName(from: url)
            )
        case "mysql", "mariadb":
            return ConnectionConfig(
                engine: scheme == "mariadb" ? .mariaDB : .mysql,
                host: url.host,
                port: url.port ?? 3306,
                username: url.user,
                password: url.password,
                database: databaseName(from: url)
            )
        case "sqlite":
            var path = url.path
            if path.hasPrefix("//") {
                path = String(path.dropFirst())
            }
            return ConnectionConfig(engine: .sqlite, filePath: path)
        default:
            throw TableFlipError.invalidConnectionURL
        }
    }

    private static func databaseName(from url: URL) -> String? {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? nil : path
    }
}

public enum HostLocality {
    public static func isLocal(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["localhost", "127.0.0.1", "::1", "0.0.0.0"].contains(trimmed)
    }
}
