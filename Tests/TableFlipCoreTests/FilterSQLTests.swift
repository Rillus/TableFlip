import Testing
@testable import TableFlipCore

@Test("F-2 contains uses bound parameters and never concatenates user SQL")
func containsFilterBindsUserValue() {
    let injection = "a'; DROP TABLE users;--"
    let bound = FilterSQL.whereClause(
        [RowFilter(column: "email", op: .contains, value: injection)],
        dialect: .sqlite
    )
    #expect(bound.sql.contains("LIKE '%' || ? || '%'"))
    #expect(!bound.sql.contains("DROP TABLE"))
    #expect(bound.parameters == [.text(injection)])
}

@Test("F-2 equals, inequality and comparisons bind the value")
func comparisonFilters() {
    let cases: [(FilterOperator, String)] = [
        (.equal, "="),
        (.notEqual, "!="),
        (.greaterThan, ">"),
        (.greaterThanOrEqual, ">="),
        (.lessThan, "<"),
        (.lessThanOrEqual, "<="),
    ]
    for (op, token) in cases {
        let bound = FilterSQL.whereClause(
            [RowFilter(column: "age", op: op, value: "30")],
            dialect: .sqlite
        )
        #expect(bound.sql.contains("\"age\" \(token) ?"))
        #expect(bound.parameters == [.text("30")])
    }
}

@Test("F-2 starts with binds the prefix and uses LIKE ? || '%'")
func startsWithFilter() {
    let bound = FilterSQL.whereClause(
        [RowFilter(column: "email", op: .startsWith, value: "ada")],
        dialect: .sqlite
    )
    #expect(bound.sql.contains("LIKE ? || '%'"))
    #expect(bound.parameters == [.text("ada")])
}

@Test("F-2 is null / is not null take no parameters")
func nullFilters() {
    let isNull = FilterSQL.whereClause(
        [RowFilter(column: "email", op: .isNull, value: "")],
        dialect: .sqlite
    )
    #expect(!isNull.sql.contains("?"))
    #expect(isNull.sql.contains("\"email\" IS NULL"))
    #expect(isNull.parameters.isEmpty)

    let notNull = FilterSQL.whereClause(
        [RowFilter(column: "email", op: .isNotNull, value: "")],
        dialect: .sqlite
    )
    #expect(notNull.sql.contains("\"email\" IS NOT NULL"))
    #expect(notNull.parameters.isEmpty)
}

@Test("F-3 multiple filters combine with AND and keep parameter order")
func multipleFiltersAnded() {
    let bound = FilterSQL.whereClause(
        [
            RowFilter(column: "email", op: .contains, value: "@"),
            RowFilter(column: "name", op: .equal, value: "Ada"),
        ],
        dialect: .sqlite
    )
    #expect(bound.sql.contains(" AND "))
    #expect(bound.parameters == [.text("@"), .text("Ada")])
}

@Test("Empty filter list produces no WHERE clause")
func emptyFilters() {
    let bound = FilterSQL.whereClause([], dialect: .sqlite)
    #expect(bound.sql.isEmpty)
    #expect(bound.parameters.isEmpty)
}

@Test("MySQL contains uses CONCAT and bound parameters")
func mysqlContains() {
    let bound = FilterSQL.whereClause(
        [RowFilter(column: "email", op: .contains, value: "a")],
        dialect: .mysql
    )
    #expect(bound.sql.contains("CONCAT('%', ?, '%')"))
    #expect(bound.parameters == [.text("a")])
}
