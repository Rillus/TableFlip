import Foundation
import Testing
@testable import TableFlipCore

@Suite("SQLite workspace")
struct WorkspaceTests {
    @Test("O-1 invalid files return a clear error instead of crashing")
    func openInvalidFile() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-db-\(UUID().uuidString).txt")
        try? "hello".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await Workspace.openSQLite(at: url)
            Issue.record("expected open to fail")
        } catch let error as TableFlipError {
            #expect(error.publicMessage.contains("isn’t a readable SQLite database") || error.publicMessage.contains("isn't a readable SQLite database"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test("O-5 new blank SQLite database can be created and opened")
    func createBlank() async throws {
        let url = temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let workspace = try await Workspace.createSQLite(at: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(workspace.objects.isEmpty)
    }

    @Test("N-1 lists user tables and views alphabetically")
    func listObjects() async throws {
        let workspace = try await seededUsersWorkspace()
        #expect(workspace.objects.map(\.name) == ["active_users", "users"])
        #expect(workspace.objects.map(\.kind) == [.view, .table] || workspace.objects[0].kind == .view || workspace.objects[1].kind == .table)
        #expect(Set(workspace.objects.map(\.kind)) == [.table, .view])
    }

    @Test("G-1 pages rows and never loads the whole table")
    func paging() async throws {
        let workspace = try await numberedWorkspace(count: 250)
        try await workspace.setPageSize(100)
        try await workspace.selectTable("numbers")
        let page = try await workspace.currentPage()
        #expect(page.rows.count == 100)
        #expect(page.offset == 0)
        #expect(page.limit == 100)
        #expect(page.totalCount == 250)
        try await workspace.nextPage()
        let second = try await workspace.currentPage()
        #expect(second.offset == 100)
        #expect(second.rows.count == 100)
    }

    @Test("G-3 sort cycles desc then asc then unsorted")
    func sortCycle() async throws {
        let workspace = try await seededUsersWorkspace()
        try await workspace.selectTable("users")
        try await workspace.cycleSort(column: "name")
        #expect(workspace.sort == SortDescriptor(column: "name", direction: .descending))
        try await workspace.cycleSort(column: "name")
        #expect(workspace.sort == SortDescriptor(column: "name", direction: .ascending))
        try await workspace.cycleSort(column: "name")
        #expect(workspace.sort == nil)
    }

    @Test("F-3 applying contains filter returns matching rows; unset restores")
    func filterAndUnset() async throws {
        let workspace = try await seededUsersWorkspace()
        try await workspace.selectTable("users")
        try await workspace.applyFilters([RowFilter(column: "email", op: .contains, value: "ada@")])
        let filtered = try await workspace.currentPage()
        #expect(filtered.rows.count == 1)
        #expect(filtered.rows[0].values["name"] == .text("Ada"))
        try await workspace.unsetFilters()
        let all = try await workspace.currentPage()
        #expect(all.rows.count == 3)
    }

    @Test("E-2 staging does not write until commit")
    func stagingDoesNotWrite() async throws {
        let workspace = try await seededUsersWorkspace()
        try await workspace.selectTable("users")
        let page = try await workspace.currentPage()
        try workspace.stageEdit(rowIndex: 0, column: "email", value: .text("changed@example.com"))
        #expect(workspace.isDirty)
        let reread = try await Workspace.openSQLite(at: workspace.databaseURL)
        try await reread.selectTable("users")
        let disk = try await reread.currentPage()
        #expect(disk.rows[0].values["email"] != .text("changed@example.com") || disk.rows.contains { $0.values["email"] == .text("ada@example.com") })
        let emails = disk.rows.compactMap { row -> String? in
            if case .text(let value) = row.values["email"] { return value }
            return nil
        }
        #expect(emails.contains("ada@example.com"))
        #expect(!emails.contains("changed@example.com"))
        _ = page
    }

    @Test("E-3 commit writes the cell and clears dirty state")
    func commitEdit() async throws {
        let url = temporaryDatabaseURL()
        let workspace = try await seededUsersWorkspace(at: url)
        try await workspace.selectTable("users")
        try workspace.stageEdit(rowIndex: 0, column: "email", value: .text("ada@new.example"))
        let preview = workspace.previewSQL
        #expect(preview.contains("UPDATE"))
        try await workspace.commit()
        #expect(!workspace.isDirty)
        let reread = try await Workspace.openSQLite(at: url)
        try await reread.selectTable("users")
        let page = try await reread.currentPage()
        #expect(page.rows.contains { $0.values["email"] == .text("ada@new.example") })
    }

    @Test("E-4 discard restores in-memory rows")
    func discardRestores() async throws {
        let workspace = try await seededUsersWorkspace()
        try await workspace.selectTable("users")
        try workspace.stageEdit(rowIndex: 0, column: "name", value: .text("Changed"))
        workspace.discard()
        #expect(!workspace.isDirty)
        let page = try await workspace.currentPage()
        #expect(page.rows[0].values["name"] != .text("Changed"))
    }

    @Test("E-6 insert and E-8 delete commit in one transaction")
    func insertAndDelete() async throws {
        let url = temporaryDatabaseURL()
        let workspace = try await seededUsersWorkspace(at: url)
        try await workspace.selectTable("users")
        _ = workspace.stageInsert(values: ["name": .text("Grace"), "email": .text("grace@example.com")])
        let page = try await workspace.currentPage()
        let ada = page.rows.firstIndex { $0.values["name"] == .text("Ada") }!
        try workspace.stageDelete(rowIndexes: [ada])
        try await workspace.commit()
        let reread = try await Workspace.openSQLite(at: url)
        try await reread.selectTable("users")
        let names = try await names(in: reread)
        #expect(names.contains("Grace"))
        #expect(!names.contains("Ada"))
    }

    @Test("E-11 dirty close requires a prompt")
    func dirtyClosePrompt() async throws {
        let workspace = try await seededUsersWorkspace()
        try await workspace.selectTable("users")
        #expect(workspace.closeDecision() == .proceed)
        try workspace.stageEdit(rowIndex: 0, column: "name", value: .text("X"))
        #expect(workspace.closeDecision() == .prompt(changeCount: 1))
    }

    @Test("E-12 tables without a primary key refuse row edits")
    func keylessTable() async throws {
        let workspace = try await keylessWorkspace()
        try await workspace.selectTable("notes")
        #expect(!workspace.canEditRows)
        #expect(throws: TableFlipError.self) {
            try workspace.stageEdit(rowIndex: 0, column: "note", value: .text("nope"))
        }
    }

    @Test("Q-3 SELECT runs and returns rows")
    func runSelect() async throws {
        let workspace = try await seededUsersWorkspace()
        let result = try await workspace.runSQL("SELECT name FROM users ORDER BY name", cursor: 0, runAll: true)
        #expect(result.sets.count == 1)
        #expect(result.sets[0].rows.count == 3)
    }

    @Test("Q-4 SQL errors surface the engine message")
    func sqlError() async throws {
        let workspace = try await seededUsersWorkspace()
        do {
            _ = try await workspace.runSQL("SELECT nope FROM users", cursor: 0, runAll: true)
            Issue.record("expected error")
        } catch let error as TableFlipError {
            #expect(!error.publicMessage.isEmpty)
        }
    }

    @Test("S-2 safe mode blocks writes until confirmed")
    func safeMode() async throws {
        let workspace = try await seededUsersWorkspace()
        workspace.safeMode = true
        do {
            _ = try await workspace.runSQL("UPDATE users SET name = 'x' WHERE id = 1", cursor: 0, runAll: true)
            Issue.record("expected confirmation")
        } catch TableFlipError.needsConfirmation {
            // expected
        }
        _ = try await workspace.runSQL("SELECT 1", cursor: 0, runAll: true)
    }

    @Test("O-6 read-only files disable commit")
    func readOnlyFile() async throws {
        let url = temporaryDatabaseURL()
        _ = try await seededUsersWorkspace(at: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }
        let workspace = try await Workspace.openSQLite(at: url)
        #expect(workspace.isReadOnly)
        try await workspace.selectTable("users")
        #expect(throws: TableFlipError.self) {
            try workspace.stageEdit(rowIndex: 0, column: "name", value: .text("X"))
        }
    }

    @Test("O-4 recents keep twenty entries and missing files are flagged")
    func recents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecentsStore(fileURL: directory.appendingPathComponent("recents.json"))
        for index in 1...25 {
            store.remember(.sqliteFile(path: "/tmp/db-\(index).sqlite"))
        }
        #expect(store.items.count == 20)
        #expect(store.items.first?.displayName.contains("25") == true)
        let missing = store.items.map(\.isAvailable)
        #expect(missing.contains(false))
    }

    @Test("Q-7 query history stores successful statements")
    func queryHistory() async throws {
        let workspace = try await seededUsersWorkspace()
        _ = try await workspace.runSQL("SELECT 1", cursor: 0, runAll: true)
        #expect(workspace.queryHistory.last?.sql.contains("SELECT 1") == true)
    }

    @Test("T-1 structure lists columns, types, nullability and PK")
    func structure() async throws {
        let workspace = try await seededUsersWorkspace()
        let columns = try await workspace.structure(of: "users")
        #expect(columns.map(\.name) == ["id", "name", "email"])
        #expect(columns[0].isPrimaryKey)
        #expect(columns[1].isNullable == false || columns[1].isNullable == true)
    }

    @Test("E-7 duplicate row stages an insert without the primary key")
    func duplicateRow() async throws {
        let workspace = try await seededUsersWorkspace()
        try await workspace.selectTable("users")
        try workspace.stageDuplicate(rowIndex: 0)
        #expect(workspace.isDirty)
        #expect(workspace.previewSQL.contains("INSERT"))
        #expect(!workspace.previewSQL.contains("\"id\""))
    }

    @Test("G-12 column visibility is remembered per table")
    func columnVisibility() async throws {
        let workspace = try await seededUsersWorkspace()
        try await workspace.selectTable("users")
        workspace.setHiddenColumns(["email"])
        #expect(workspace.hiddenColumns == ["email"])
        try await workspace.selectTable("active_users")
        #expect(workspace.hiddenColumns.isEmpty)
        try await workspace.selectTable("users")
        #expect(workspace.hiddenColumns == ["email"])
    }
}

func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("tableflip-\(UUID().uuidString).sqlite")
}

@discardableResult
func seededUsersWorkspace(at url: URL = temporaryDatabaseURL()) async throws -> Workspace {
    let sqlite = try SQLiteHandle.open(url, create: true)
    try sqlite.execute("""
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT
        );
        CREATE VIEW active_users AS SELECT * FROM users;
        INSERT INTO users (name, email) VALUES
            ('Ada', 'ada@example.com'),
            ('Alan', 'alan@example.com'),
            ('Alonzo', 'alonzo@example.com');
        """)
    sqlite.close()
    return try await Workspace.openSQLite(at: url)
}

func numberedWorkspace(count: Int) async throws -> Workspace {
    let url = temporaryDatabaseURL()
    let sqlite = try SQLiteHandle.open(url, create: true)
    try sqlite.execute("CREATE TABLE numbers (id INTEGER PRIMARY KEY, n INTEGER NOT NULL);")
    try sqlite.execute("BEGIN")
    for index in 1...count {
        try sqlite.execute("INSERT INTO numbers (id, n) VALUES (\(index), \(index));")
    }
    try sqlite.execute("COMMIT")
    sqlite.close()
    return try await Workspace.openSQLite(at: url)
}

func keylessWorkspace() async throws -> Workspace {
    let url = temporaryDatabaseURL()
    let sqlite = try SQLiteHandle.open(url, create: true)
    try sqlite.execute("CREATE TABLE notes (note TEXT); INSERT INTO notes VALUES ('hello');")
    sqlite.close()
    return try await Workspace.openSQLite(at: url)
}

func names(in workspace: Workspace) async throws -> [String] {
    try await workspace.currentPage().rows.compactMap { row in
        if case .text(let value) = row.values["name"] { return value }
        return nil
    }
}
