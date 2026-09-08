public enum Identifier {
    public static func quote(_ name: String, dialect: SQLDialect) -> String {
        switch dialect {
        case .sqlite, .postgres:
            let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        case .mysql:
            let escaped = name.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        }
    }

    public static func qualify(schema: String?, name: String, dialect: SQLDialect) -> String {
        if let schema, !schema.isEmpty {
            return "\(quote(schema, dialect: dialect)).\(quote(name, dialect: dialect))"
        }
        return quote(name, dialect: dialect)
    }
}

public enum FilterSQL {
    public static func whereClause(_ filters: [RowFilter], dialect: SQLDialect) -> BoundSQL {
        guard !filters.isEmpty else {
            return BoundSQL(sql: "", parameters: [])
        }
        var fragments: [String] = []
        var parameters: [CellValue] = []
        for filter in filters {
            let column = Identifier.quote(filter.column, dialect: dialect)
            switch filter.op {
            case .equal:
                fragments.append("\(column) = ?")
                parameters.append(.text(filter.value))
            case .notEqual:
                fragments.append("\(column) != ?")
                parameters.append(.text(filter.value))
            case .greaterThan:
                fragments.append("\(column) > ?")
                parameters.append(.text(filter.value))
            case .greaterThanOrEqual:
                fragments.append("\(column) >= ?")
                parameters.append(.text(filter.value))
            case .lessThan:
                fragments.append("\(column) < ?")
                parameters.append(.text(filter.value))
            case .lessThanOrEqual:
                fragments.append("\(column) <= ?")
                parameters.append(.text(filter.value))
            case .contains:
                switch dialect {
                case .mysql:
                    fragments.append("\(column) LIKE CONCAT('%', ?, '%')")
                case .sqlite, .postgres:
                    fragments.append("\(column) LIKE '%' || ? || '%'")
                }
                parameters.append(.text(filter.value))
            case .startsWith:
                switch dialect {
                case .mysql:
                    fragments.append("\(column) LIKE CONCAT(?, '%')")
                case .sqlite, .postgres:
                    fragments.append("\(column) LIKE ? || '%'")
                }
                parameters.append(.text(filter.value))
            case .isNull:
                fragments.append("\(column) IS NULL")
            case .isNotNull:
                fragments.append("\(column) IS NOT NULL")
            }
        }
        return BoundSQL(sql: fragments.joined(separator: " AND "), parameters: parameters)
    }
}
