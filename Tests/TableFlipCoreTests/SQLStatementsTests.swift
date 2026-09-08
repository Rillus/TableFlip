import Testing
@testable import TableFlipCore

@Test("Q-3 splits statements on semicolons outside quotes")
func splitStatements() {
    let sql = "SELECT 1; SELECT 'a;b'; "
    let parts = SQLStatements.split(sql)
    #expect(parts == ["SELECT 1", "SELECT 'a;b'"])
}

@Test("Q-3 current statement is the one containing the cursor")
func currentStatement() {
    let sql = "SELECT 1; SELECT 2; SELECT 3"
    #expect(SQLStatements.current(in: sql, cursor: 0) == "SELECT 1")
    #expect(SQLStatements.current(in: sql, cursor: 12) == "SELECT 2")
}

@Test("Q-5 SELECT without LIMIT is wrapped with a safety cap")
func limitSafety() {
    let capped = QuerySafety.cappedSelect("SELECT * FROM users", cap: 1000)
    #expect(capped.contains("LIMIT 1000"))
    let already = QuerySafety.cappedSelect("SELECT * FROM users LIMIT 5", cap: 1000)
    #expect(already == "SELECT * FROM users LIMIT 5")
}

@Test("Q-6 write detection for editor statements")
func writeDetection() {
    #expect(QuerySafety.isWrite("UPDATE users SET name = 'x'"))
    #expect(QuerySafety.isWrite("delete from users"))
    #expect(!QuerySafety.isWrite("SELECT * FROM users"))
    #expect(!QuerySafety.isWrite("EXPLAIN SELECT 1"))
}
