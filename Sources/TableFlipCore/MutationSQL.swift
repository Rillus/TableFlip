public enum MutationSQL {
    public static func statements(
        table: TableIdentity,
        changes: [PendingChange],
        dialect: SQLDialect
    ) -> [BoundSQL] {
        let tableName = Identifier.qualify(schema: table.schema, name: table.name, dialect: dialect)
        return changes.map { change in
            statement(tableName: tableName, table: table, change: change, dialect: dialect)
        }
    }

    public static func preview(
        table: TableIdentity,
        changes: [PendingChange],
        dialect: SQLDialect
    ) -> String {
        statements(table: table, changes: changes, dialect: dialect)
            .map { interpolate($0) }
            .joined(separator: ";\n")
    }

    private static func statement(
        tableName: String,
        table: TableIdentity,
        change: PendingChange,
        dialect: SQLDialect
    ) -> BoundSQL {
        switch change {
        case .insert(let values):
            let keys = values.keys.sorted()
            let columns = keys.map { Identifier.quote($0, dialect: dialect) }.joined(separator: ", ")
            let placeholders = Array(repeating: "?", count: keys.count).joined(separator: ", ")
            return BoundSQL(
                sql: "INSERT INTO \(tableName) (\(columns)) VALUES (\(placeholders))",
                parameters: keys.map { values[$0]! }
            )
        case .update(let identity, let set):
            let keys = set.keys.sorted()
            let assignments = keys.map { "\(Identifier.quote($0, dialect: dialect)) = ?" }.joined(separator: ", ")
            let (whereSQL, whereParams) = identityClause(identity, dialect: dialect)
            return BoundSQL(
                sql: "UPDATE \(tableName) SET \(assignments) WHERE \(whereSQL)",
                parameters: keys.map { set[$0]! } + whereParams
            )
        case .delete(let identity):
            let (whereSQL, whereParams) = identityClause(identity, dialect: dialect)
            return BoundSQL(
                sql: "DELETE FROM \(tableName) WHERE \(whereSQL)",
                parameters: whereParams
            )
        }
    }

    private static func identityClause(_ identity: [String: CellValue], dialect: SQLDialect) -> (String, [CellValue]) {
        let keys = identity.keys.sorted()
        let sql = keys.map { "\(Identifier.quote($0, dialect: dialect)) = ?" }.joined(separator: " AND ")
        return (sql, keys.map { identity[$0]! })
    }

    static func interpolate(_ bound: BoundSQL) -> String {
        var sql = bound.sql
        for parameter in bound.parameters {
            guard let range = sql.range(of: "?") else { break }
            sql.replaceSubrange(range, with: literal(parameter))
        }
        return sql
    }

    public static func literal(_ value: CellValue) -> String {
        switch value {
        case .null:
            return "NULL"
        case .integer(let number):
            return String(number)
        case .double(let number):
            return String(number)
        case .text(let text):
            return "'\(text.replacingOccurrences(of: "'", with: "''"))'"
        case .blob(let data):
            return "X'\(data.map { String(format: "%02X", $0) }.joined())'"
        }
    }
}
