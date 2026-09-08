import Testing
@testable import TableFlipCore

@Test("G-8 copy as TSV, CSV, JSON, Markdown and SQL INSERT")
func copyFormats() {
    let columns = ["id", "name"]
    let rows: [[CellValue]] = [
        [.integer(1), .text("Ada")],
        [.integer(2), .null],
    ]
    #expect(CopyFormat.tsv(columns: columns, rows: rows) == "1\tAda\n2\t\\N")
    #expect(CopyFormat.csv(columns: columns, rows: rows) == "id,name\n1,Ada\n2,")
    #expect(CopyFormat.json(columns: columns, rows: rows).contains("\"name\":\"Ada\""))
    #expect(CopyFormat.markdown(columns: columns, rows: rows).contains("| id | name |"))
    let insert = CopyFormat.sqlInsert(table: "users", columns: columns, rows: rows, dialect: .sqlite)
    #expect(insert.contains("INSERT INTO \"users\""))
    #expect(insert.contains("NULL"))
}
