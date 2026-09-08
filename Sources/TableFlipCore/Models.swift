import Foundation

public enum TableFlipError: Error, Equatable {
    case invalidSQLiteFile
    case readOnly
    case notEditable
    case needsConfirmation
    case engine(String)
    case invalidConnectionURL
    case csv(String)
    case outOfBounds
    case missingTable(String)

    public var publicMessage: String {
        switch self {
        case .invalidSQLiteFile:
            return "This file isn't a readable SQLite database."
        case .readOnly:
            return "This database is read-only, so changes can’t be committed."
        case .notEditable:
            return "This table has no primary key, so rows can’t be edited in the grid."
        case .needsConfirmation:
            return "Safe mode is on. Confirm before running this write."
        case .engine(let message):
            return message
        case .invalidConnectionURL:
            return "That connection URL couldn’t be parsed."
        case .csv(let message):
            return message
        case .outOfBounds:
            return "That row is not on the current page."
        case .missingTable(let name):
            return "There is no table named \(name)."
        }
    }
}

public enum SQLDialect: Sendable, Equatable {
    case sqlite
    case postgres
    case mysql
}

public enum EngineKind: Sendable, Equatable, Hashable {
    case sqlite
    case postgres
    case mysql
    case mariaDB
}

public enum CellValue: Sendable, Equatable {
    case null
    case integer(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
}

public struct BoundSQL: Sendable, Equatable {
    public var sql: String
    public var parameters: [CellValue]

    public init(sql: String, parameters: [CellValue] = []) {
        self.sql = sql
        self.parameters = parameters
    }
}

public enum FilterOperator: String, Sendable, Equatable, CaseIterable, Hashable {
    case equal
    case notEqual
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case contains
    case startsWith
    case isNull
    case isNotNull
}

public struct RowFilter: Sendable, Equatable {
    public var column: String
    public var op: FilterOperator
    public var value: String

    public init(column: String, op: FilterOperator, value: String) {
        self.column = column
        self.op = op
        self.value = value
    }
}

public struct Column: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var declaredType: String
    public var isPrimaryKey: Bool
    public var isNullable: Bool
    public var defaultValue: String?

    public init(
        name: String,
        declaredType: String,
        isPrimaryKey: Bool,
        isNullable: Bool,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.declaredType = declaredType
        self.isPrimaryKey = isPrimaryKey
        self.isNullable = isNullable
        self.defaultValue = defaultValue
    }
}

public struct DatabaseObject: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case table
        case view
    }

    public var kind: Kind
    public var schema: String?
    public var name: String

    public init(kind: Kind, schema: String?, name: String) {
        self.kind = kind
        self.schema = schema
        self.name = name
    }
}

public struct TableIdentity: Sendable, Equatable {
    public var schema: String?
    public var name: String
    public var identityColumns: [String]

    public init(schema: String?, name: String, identityColumns: [String]) {
        self.schema = schema
        self.name = name
        self.identityColumns = identityColumns
    }
}

public enum SortDirection: Sendable, Equatable {
    case ascending
    case descending
}

public struct SortDescriptor: Sendable, Equatable {
    public var column: String
    public var direction: SortDirection

    public init(column: String, direction: SortDirection) {
        self.column = column
        self.direction = direction
    }
}

public enum RowState: Sendable, Equatable {
    case clean
    case updated
    case pendingInsert
    case pendingDelete
}

public struct GridRow: Sendable, Equatable {
    public var identity: [String: CellValue]
    public var values: [String: CellValue]
    public var state: RowState

    public init(identity: [String: CellValue], values: [String: CellValue], state: RowState = .clean) {
        self.identity = identity
        self.values = values
        self.state = state
    }
}

public struct GridPage: Sendable, Equatable {
    public var columns: [Column]
    public var rows: [GridRow]
    public var offset: Int
    public var limit: Int
    public var totalCount: Int

    public init(columns: [Column], rows: [GridRow], offset: Int, limit: Int, totalCount: Int) {
        self.columns = columns
        self.rows = rows
        self.offset = offset
        self.limit = limit
        self.totalCount = totalCount
    }
}

public enum PendingChange: Sendable, Equatable {
    case update(identity: [String: CellValue], set: [String: CellValue])
    case insert([String: CellValue])
    case delete(identity: [String: CellValue])
}

public enum CloseDecision: Sendable, Equatable {
    case proceed
    case prompt(changeCount: Int)
}

public struct QueryResultSet: Sendable, Equatable {
    public var columns: [String]
    public var rows: [[CellValue]]

    public init(columns: [String], rows: [[CellValue]]) {
        self.columns = columns
        self.rows = rows
    }
}

public struct QueryResult: Sendable, Equatable {
    public var sets: [QueryResultSet]

    public init(sets: [QueryResultSet]) {
        self.sets = sets
    }
}

public struct QueryHistoryItem: Sendable, Equatable {
    public var sql: String
    public var ranAt: Date

    public init(sql: String, ranAt: Date = Date()) {
        self.sql = sql
        self.ranAt = ranAt
    }
}

public struct ConnectionConfig: Sendable, Equatable {
    public var engine: EngineKind
    public var host: String?
    public var port: Int?
    public var username: String?
    public var password: String?
    public var database: String?
    public var filePath: String?
    public var ssl: Bool

    public init(
        engine: EngineKind,
        host: String? = nil,
        port: Int? = nil,
        username: String? = nil,
        password: String? = nil,
        database: String? = nil,
        filePath: String? = nil,
        ssl: Bool = false
    ) {
        self.engine = engine
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.filePath = filePath
        self.ssl = ssl
    }
}
