import Testing
@testable import TableFlipCore

private let users = TableIdentity(
    schema: nil,
    name: "users",
    identityColumns: ["id"]
)

@Test("E-3 update emits bound UPDATE ... WHERE pk = ?")
func updateSQL() {
    let statements = MutationSQL.statements(
        table: users,
        changes: [
            .update(
                identity: ["id": .integer(1)],
                set: ["email": .text("ada@example.com")]
            ),
        ],
        dialect: .sqlite
    )
    #expect(statements.count == 1)
    #expect(statements[0].sql == "UPDATE \"users\" SET \"email\" = ? WHERE \"id\" = ?")
    #expect(statements[0].parameters == [.text("ada@example.com"), .integer(1)])
}

@Test("E-9 setting NULL emits NULL not empty string")
func updateNullSQL() {
    let statements = MutationSQL.statements(
        table: users,
        changes: [
            .update(
                identity: ["id": .integer(1)],
                set: ["email": .null]
            ),
        ],
        dialect: .sqlite
    )
    #expect(statements[0].sql.contains("\"email\" = ?"))
    #expect(statements[0].parameters.first == .null)
}

@Test("E-6 insert emits bound INSERT")
func insertSQL() {
    let statements = MutationSQL.statements(
        table: users,
        changes: [
            .insert(["name": .text("Ada"), "email": .text("ada@example.com")]),
        ],
        dialect: .sqlite
    )
    #expect(statements[0].sql.hasPrefix("INSERT INTO \"users\""))
    #expect(statements[0].sql.contains("?"))
    #expect(statements[0].parameters.contains(.text("Ada")))
}

@Test("E-8 delete emits DELETE WHERE pk = ?")
func deleteSQL() {
    let statements = MutationSQL.statements(
        table: users,
        changes: [
            .delete(identity: ["id": .integer(7)]),
        ],
        dialect: .sqlite
    )
    #expect(statements[0].sql == "DELETE FROM \"users\" WHERE \"id\" = ?")
    #expect(statements[0].parameters == [.integer(7)])
}

@Test("E-5 preview interpolates values for review without using them as executable SQL")
func previewSQLIsHumanReadable() {
    let preview = MutationSQL.preview(
        table: users,
        changes: [
            .update(
                identity: ["id": .integer(1)],
                set: ["email": .text("ada@example.com")]
            ),
        ],
        dialect: .sqlite
    )
    #expect(preview.contains("UPDATE \"users\" SET \"email\" = 'ada@example.com' WHERE \"id\" = 1"))
}

@Test("S-3 multiple changes stay as separate statements for one transaction")
func multipleChangesOrder() {
    let statements = MutationSQL.statements(
        table: users,
        changes: [
            .insert(["name": .text("A")]),
            .update(identity: ["id": .integer(1)], set: ["name": .text("B")]),
            .delete(identity: ["id": .integer(2)]),
        ],
        dialect: .sqlite
    )
    #expect(statements.count == 3)
    #expect(statements[0].sql.hasPrefix("INSERT"))
    #expect(statements[1].sql.hasPrefix("UPDATE"))
    #expect(statements[2].sql.hasPrefix("DELETE"))
}
