import Testing
@testable import TableFlipCore

@Test("SQLite identifiers are double-quoted and internal quotes doubled")
func sqliteIdentifierQuoting() {
    #expect(Identifier.quote("users", dialect: .sqlite) == "\"users\"")
    #expect(Identifier.quote("weird\"name", dialect: .sqlite) == "\"weird\"\"name\"")
}

@Test("Postgres identifiers are double-quoted")
func postgresIdentifierQuoting() {
    #expect(Identifier.quote("Users", dialect: .postgres) == "\"Users\"")
}

@Test("MySQL identifiers are backtick-quoted")
func mysqlIdentifierQuoting() {
    #expect(Identifier.quote("users", dialect: .mysql) == "`users`")
    #expect(Identifier.quote("we`ird", dialect: .mysql) == "`we``ird`")
}
