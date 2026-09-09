import Testing
@testable import TableFlipCore

@Test("T-3 CSV import maps headers and treats missing cells as NULL")
func csvImport() throws {
    let csv = "name,email\nAda,ada@example.com\nGrace,\n"
    let rows = try CSVImport.parse(csv, hasHeader: true)
    #expect(rows.columns == ["name", "email"])
    #expect(rows.records.count == 2)
    #expect(rows.records[0]["email"] == .text("ada@example.com"))
    #expect(rows.records[1]["email"] == .null)
}

@Test("T-2 CSV export includes header and quotes commas")
func csvExport() {
    let csv = CSVExport.serialize(
        columns: ["name", "note"],
        rows: [[.text("Ada"), .text("hello, world")]]
    )
    #expect(csv == "name,note\nAda,\"hello, world\"\n")
}
