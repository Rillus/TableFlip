import Foundation
import CSQLite

final class SQLiteHandle {
    private var db: OpaquePointer?

    var isOpen: Bool { db != nil }

    static func open(_ url: URL, create: Bool, readOnly: Bool = false) throws -> SQLiteHandle {
        if create {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } else {
            try validateExisting(url)
        }

        let flags: Int32
        if readOnly {
            flags = SQLITE_OPEN_READONLY
        } else if create {
            flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        } else {
            flags = SQLITE_OPEN_READWRITE
        }

        var handle: OpaquePointer?
        let status = url.path.withCString { path in
            sqlite3_open_v2(path, &handle, flags, nil)
        }
        let opened = SQLiteHandle(db: handle)
        if status != SQLITE_OK {
            let message = opened.errorMessage
            opened.close()
            throw TableFlipError.engine(message)
        }
        return opened
    }

    private init(db: OpaquePointer?) {
        self.db = db
    }

    deinit {
        close()
    }

    func close() {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &errorPointer)
        let message = errorPointer.map { String(cString: $0) }
        sqlite3_free(errorPointer)
        if status != SQLITE_OK {
            throw TableFlipError.engine(message ?? errorMessage)
        }
    }

    func run(_ bound: BoundSQL) throws {
        var statement: OpaquePointer?
        try check(sqlite3_prepare_v2(db, bound.sql, -1, &statement, nil))
        defer { sqlite3_finalize(statement) }
        try bind(statement, bound.parameters)
        let status = sqlite3_step(statement)
        if status != SQLITE_DONE && status != SQLITE_ROW {
            throw TableFlipError.engine(errorMessage)
        }
    }

    func query(_ sql: String, parameters: [CellValue] = []) throws -> QueryResultSet {
        var statement: OpaquePointer?
        try check(sqlite3_prepare_v2(db, sql, -1, &statement, nil))
        defer { sqlite3_finalize(statement) }
        try bind(statement, parameters)
        let columnCount = Int(sqlite3_column_count(statement))
        var columns: [String] = []
        for index in 0..<columnCount {
            let name = sqlite3_column_name(statement, Int32(index)).map { String(cString: $0) } ?? "column_\(index)"
            columns.append(name)
        }
        var rows: [[CellValue]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { break }
            if status != SQLITE_ROW {
                throw TableFlipError.engine(errorMessage)
            }
            var row: [CellValue] = []
            for index in 0..<columnCount {
                row.append(readColumn(statement, index: Int32(index)))
            }
            rows.append(row)
        }
        return QueryResultSet(columns: columns, rows: rows)
    }

    var errorMessage: String {
        guard let db else { return "SQLite is not open." }
        return String(cString: sqlite3_errmsg(db))
    }

    private func bind(_ statement: OpaquePointer?, _ parameters: [CellValue]) throws {
        for (index, value) in parameters.enumerated() {
            let slot = Int32(index + 1)
            let status: Int32
            switch value {
            case .null:
                status = sqlite3_bind_null(statement, slot)
            case .integer(let number):
                status = sqlite3_bind_int64(statement, slot, number)
            case .double(let number):
                status = sqlite3_bind_double(statement, slot, number)
            case .text(let text):
                status = sqlite3_bind_text(statement, slot, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .blob(let data):
                status = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, slot, bytes.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            }
            try check(status)
        }
    }

    private func readColumn(_ statement: OpaquePointer?, index: Int32) -> CellValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return .double(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            if let pointer = sqlite3_column_text(statement, index) {
                return .text(String(cString: pointer))
            }
            return .null
        case SQLITE_BLOB:
            let length = Int(sqlite3_column_bytes(statement, index))
            if let pointer = sqlite3_column_blob(statement, index) {
                return .blob(Data(bytes: pointer, count: length))
            }
            return .blob(Data())
        default:
            return .null
        }
    }

    private func check(_ status: Int32) throws {
        if status != SQLITE_OK {
            throw TableFlipError.engine(errorMessage)
        }
    }

    private static func validateExisting(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TableFlipError.invalidSQLiteFile
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        if data.isEmpty { return }
        let magic = "SQLite format 3".data(using: .utf8)!
        if !data.starts(with: magic) {
            throw TableFlipError.invalidSQLiteFile
        }
    }
}

enum SQLiteSchema {
    static func objects(_ handle: SQLiteHandle) throws -> [DatabaseObject] {
        let result = try handle.query(
            """
            SELECT name, type FROM sqlite_master
            WHERE type IN ('table', 'view')
              AND name NOT LIKE 'sqlite_%'
            ORDER BY name COLLATE NOCASE
            """
        )
        return result.rows.compactMap { row in
            guard case .text(let name) = row[0], case .text(let type) = row[1] else { return nil }
            return DatabaseObject(kind: type == "view" ? .view : .table, schema: nil, name: name)
        }
    }

    static func columns(_ handle: SQLiteHandle, table: String) throws -> [Column] {
        let quoted = Identifier.quote(table, dialect: .sqlite)
        let result = try handle.query("PRAGMA table_info(\(quoted))")
        return result.rows.map { row in
            let name = string(row[1]) ?? ""
            let type = string(row[2]) ?? ""
            let notNull = int(row[3]) == 1
            let defaultValue = string(row[4])
            let pk = int(row[5]).map { $0 > 0 } ?? false
            return Column(
                name: name,
                declaredType: type,
                isPrimaryKey: pk,
                isNullable: !notNull,
                defaultValue: defaultValue
            )
        }
    }

    private static func string(_ value: CellValue) -> String? {
        switch value {
        case .text(let text): return text
        case .integer(let number): return String(number)
        case .null: return nil
        default: return nil
        }
    }

    private static func int(_ value: CellValue) -> Int64? {
        if case .integer(let number) = value { return number }
        return nil
    }
}
