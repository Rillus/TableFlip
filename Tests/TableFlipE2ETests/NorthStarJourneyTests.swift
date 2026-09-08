import Foundation
import Testing
@testable import TableFlipCore

@Suite("MVP end-to-end journeys")
struct NorthStarJourneyTests {
    @Test("9.1 open a SQLite file, filter, edit a cell, commit, and persist after reopen")
    func editEmailAndPersist() async throws {
        let url = try FixtureDatabase.users()
        defer { try? FileManager.default.removeItem(at: url) }

        let workspace = try await Workspace.openSQLite(at: url)
        try await workspace.selectTable("users")
        try await workspace.applyFilters([RowFilter(column: "email", op: .contains, value: "ada@")])
        var page = try await workspace.currentPage()
        #expect(page.rows.count == 1)

        try workspace.stageEdit(rowIndex: 0, column: "email", value: .text("ada@new.example"))
        #expect(workspace.isDirty)
        #expect(workspace.previewSQL.contains("UPDATE"))
        #expect(workspace.previewSQL.contains("ada@new.example"))
        try await workspace.commit()
        #expect(!workspace.isDirty)

        let reread = try await Workspace.openSQLite(at: url)
        try await reread.selectTable("users")
        try await reread.applyFilters([RowFilter(column: "email", op: .equal, value: "ada@new.example")])
        page = try await reread.currentPage()
        #expect(page.rows.count == 1)
        #expect(page.rows[0].values["name"] == .text("Ada"))
    }

    @Test("9.4 pending deletes are discarded without writing")
    func discardDeletes() async throws {
        let url = try FixtureDatabase.users()
        defer { try? FileManager.default.removeItem(at: url) }

        let workspace = try await Workspace.openSQLite(at: url)
        try await workspace.selectTable("users")
        let before = try await workspace.currentPage()
        try workspace.stageDelete(rowIndexes: Array(before.rows.indices))
        #expect(workspace.previewSQL.contains("DELETE"))
        workspace.discard()
        #expect(!workspace.isDirty)

        let reread = try await Workspace.openSQLite(at: url)
        try await reread.selectTable("users")
        let after = try await reread.currentPage()
        #expect(after.totalCount == 3)
    }

    @Test("9.3 query editor SELECT returns rows; Safe mode blocks UPDATE")
    func queryEditorAndSafeMode() async throws {
        let url = try FixtureDatabase.users()
        defer { try? FileManager.default.removeItem(at: url) }

        let workspace = try await Workspace.openSQLite(at: url)
        let selected = try await workspace.runSQL(
            "SELECT name FROM users WHERE email LIKE '%example.com' ORDER BY name",
            cursor: 0,
            runAll: true
        )
        #expect(selected.sets[0].rows.count == 3)

        workspace.safeMode = true
        do {
            _ = try await workspace.runSQL("UPDATE users SET name = 'x'", cursor: 0, runAll: true)
            Issue.record("Safe mode should require confirmation")
        } catch TableFlipError.needsConfirmation {
            let check = try await workspace.runSQL("SELECT name FROM users WHERE name = 'x'", cursor: 0, runAll: true)
            #expect(check.sets[0].rows.isEmpty)
        }
    }

    @Test("empty, keyless, wide and JSON fixtures open without crashing")
    func awkwardFixtures() async throws {
        let empty = try FixtureDatabase.empty()
        defer { try? FileManager.default.removeItem(at: empty) }
        let emptyWorkspace = try await Workspace.openSQLite(at: empty)
        #expect(emptyWorkspace.objects.isEmpty)

        let keyless = try FixtureDatabase.keyless()
        defer { try? FileManager.default.removeItem(at: keyless) }
        let notes = try await Workspace.openSQLite(at: keyless)
        try await notes.selectTable("notes")
        #expect(!notes.canEditRows)

        let wide = try FixtureDatabase.wide()
        defer { try? FileManager.default.removeItem(at: wide) }
        let wideWorkspace = try await Workspace.openSQLite(at: wide)
        try await wideWorkspace.selectTable("wide")
        let page = try await wideWorkspace.currentPage()
        #expect(page.columns.count == 80)

        let json = try FixtureDatabase.json()
        defer { try? FileManager.default.removeItem(at: json) }
        let jsonWorkspace = try await Workspace.openSQLite(at: json)
        try await jsonWorkspace.selectTable("events")
        let jsonPage = try await jsonWorkspace.currentPage()
        #expect(jsonPage.rows[0].values["payload"] != nil)
    }

    @Test("CSV import stages rows then commit inserts them")
    func csvImportCommit() async throws {
        let url = try FixtureDatabase.users()
        defer { try? FileManager.default.removeItem(at: url) }
        let workspace = try await Workspace.openSQLite(at: url)
        try await workspace.selectTable("users")
        try workspace.stageImportedCSV("name,email\nGrace,grace@example.com\n")
        try await workspace.commit()
        try await workspace.unsetFilters()
        try await workspace.applyFilters([RowFilter(column: "name", op: .equal, value: "Grace")])
        let page = try await workspace.currentPage()
        #expect(page.rows.count == 1)
    }
}

enum FixtureDatabase {
    static func users() throws -> URL {
        try write("""
            CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT
            );
            INSERT INTO users (name, email) VALUES
                ('Ada', 'ada@example.com'),
                ('Alan', 'alan@example.com'),
                ('Alonzo', 'alonzo@example.com');
            """)
    }

    static func empty() throws -> URL {
        try write("")
    }

    static func keyless() throws -> URL {
        try write("CREATE TABLE notes (note TEXT); INSERT INTO notes VALUES ('hello');")
    }

    static func wide() throws -> URL {
        let columns = (1...79).map { "c\($0) TEXT" }.joined(separator: ", ")
        let names = (1...79).map { "c\($0)" }.joined(separator: ", ")
        let values = (1...79).map { _ in "'x'" }.joined(separator: ", ")
        return try write("CREATE TABLE wide (id INTEGER PRIMARY KEY, \(columns)); INSERT INTO wide (id, \(names)) VALUES (1, \(values));")
    }

    static func json() throws -> URL {
        try write("CREATE TABLE events (id INTEGER PRIMARY KEY, payload TEXT); INSERT INTO events (payload) VALUES ('{\"ok\":true}');")
    }

    private static func write(_ sql: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("e2e-\(UUID().uuidString).sqlite")
        let handle = try SQLiteHandle.open(url, create: true)
        if !sql.isEmpty {
            try handle.execute(sql)
        }
        handle.close()
        return url
    }
}
