import Foundation

public final class Workspace {
    public let databaseURL: URL
    public private(set) var objects: [DatabaseObject]
    public private(set) var isReadOnly: Bool
    public private(set) var sort: SortDescriptor?
    public private(set) var queryHistory: [QueryHistoryItem] = []
    public var safeMode = false

    private let handle: SQLiteHandle
    private var pageSize = 100
    private var offset = 0
    private var filters: [RowFilter] = []
    private var currentTable: String?
    private var currentColumns: [Column] = []
    private var loadedRows: [GridRow] = []
    private var pending: [PendingChange] = []
    private var hiddenColumnsByTable: [String: [String]] = [:]
    private var loadedFilemtime: Date?
    private var totalCount = 0

    public var isDirty: Bool { !pending.isEmpty }

    public var canEditRows: Bool {
        !isReadOnly && currentColumns.contains(where: \.isPrimaryKey)
    }

    public var hiddenColumns: [String] {
        guard let currentTable else { return [] }
        return hiddenColumnsByTable[currentTable] ?? []
    }

    public var previewSQL: String {
        guard let table else { return "" }
        return MutationSQL.preview(table: table, changes: pending, dialect: .sqlite)
    }

    public var generatedWhereSQL: BoundSQL {
        FilterSQL.whereClause(filters, dialect: .sqlite)
    }

    private var table: TableIdentity? {
        guard let currentTable else { return nil }
        return TableIdentity(
            schema: nil,
            name: currentTable,
            identityColumns: currentColumns.filter(\.isPrimaryKey).map(\.name)
        )
    }

    public static func openSQLite(at url: URL) async throws -> Workspace {
        let readOnly = !FileManager.default.isWritableFile(atPath: url.path)
        let handle = try SQLiteHandle.open(url, create: false, readOnly: readOnly)
        return try Workspace(url: url, handle: handle, readOnly: readOnly)
    }

    public static func createSQLite(at url: URL) async throws -> Workspace {
        let handle = try SQLiteHandle.open(url, create: true)
        handle.close()
        return try await openSQLite(at: url)
    }

    private init(url: URL, handle: SQLiteHandle, readOnly: Bool) throws {
        self.databaseURL = url
        self.handle = handle
        self.isReadOnly = readOnly
        self.objects = try SQLiteSchema.objects(handle)
        self.loadedFilemtime = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    public func selectTable(_ name: String) async throws {
        guard objects.contains(where: { $0.name == name }) else {
            throw TableFlipError.missingTable(name)
        }
        currentTable = name
        currentColumns = try SQLiteSchema.columns(handle, table: name)
        offset = 0
        try reloadPage()
    }

    public func currentPage() async throws -> GridPage {
        try reloadPage()
        return GridPage(
            columns: currentColumns,
            rows: loadedRows,
            offset: offset,
            limit: pageSize,
            totalCount: totalCount
        )
    }

    public func setPageSize(_ size: Int) async throws {
        pageSize = max(1, size)
        offset = 0
        if currentTable != nil {
            try reloadPage()
        }
    }

    public func nextPage() async throws {
        if offset + pageSize < totalCount {
            offset += pageSize
            try reloadPage()
        }
    }

    public func previousPage() async throws {
        offset = max(0, offset - pageSize)
        try reloadPage()
    }

    public func applyFilters(_ filters: [RowFilter]) async throws {
        self.filters = filters
        offset = 0
        try reloadPage()
    }

    public func unsetFilters() async throws {
        filters = []
        offset = 0
        try reloadPage()
    }

    public func cycleSort(column: String) async throws {
        if sort?.column != column {
            sort = SortDescriptor(column: column, direction: .descending)
        } else if sort?.direction == .descending {
            sort = SortDescriptor(column: column, direction: .ascending)
        } else {
            sort = nil
        }
        try reloadPage()
    }

    public func stageEdit(rowIndex: Int, column: String, value: CellValue) throws {
        try ensureEditable()
        guard loadedRows.indices.contains(rowIndex) else { throw TableFlipError.outOfBounds }
        if loadedRows[rowIndex].state == .pendingInsert {
            loadedRows[rowIndex].values[column] = value
            rewriteInsert(at: rowIndex)
            return
        }
        loadedRows[rowIndex].values[column] = value
        loadedRows[rowIndex].state = loadedRows[rowIndex].state == .pendingDelete ? .pendingDelete : .updated
        let identity = loadedRows[rowIndex].identity
        if let index = pending.firstIndex(where: { change in
            if case .update(let existing, _) = change { return existing == identity }
            return false
        }), case .update(_, var set) = pending[index] {
            set[column] = value
            pending[index] = .update(identity: identity, set: set)
        } else {
            pending.append(.update(identity: identity, set: [column: value]))
        }
    }

    public func stageInsert(values: [String: CellValue]) -> Int {
        pending.append(.insert(values))
        loadedRows.append(GridRow(identity: [:], values: values, state: .pendingInsert))
        return loadedRows.count - 1
    }

    public func stageDelete(rowIndexes: [Int]) throws {
        try ensureEditable()
        for index in rowIndexes.sorted(by: >) {
            guard loadedRows.indices.contains(index) else { throw TableFlipError.outOfBounds }
            if loadedRows[index].state == .pendingInsert {
                loadedRows.remove(at: index)
                rewritePendingInserts()
                continue
            }
            loadedRows[index].state = .pendingDelete
            pending.append(.delete(identity: loadedRows[index].identity))
        }
    }

    public func stageDuplicate(rowIndex: Int) throws {
        try ensureEditable()
        guard loadedRows.indices.contains(rowIndex) else { throw TableFlipError.outOfBounds }
        var values = loadedRows[rowIndex].values
        for column in currentColumns where column.isPrimaryKey {
            values.removeValue(forKey: column.name)
        }
        _ = stageInsert(values: values)
    }

    public func discard() {
        pending = []
        try? reloadPage()
    }

    public func commit() async throws {
        try ensureEditable()
        guard !pending.isEmpty, let table else { return }
        if safeMode {
            throw TableFlipError.needsConfirmation
        }
        try warnIfFileChanged()
        let statements = MutationSQL.statements(table: table, changes: pending, dialect: .sqlite)
        do {
            try handle.execute("BEGIN")
            for statement in statements {
                try handle.run(statement)
            }
            try handle.execute("COMMIT")
        } catch {
            try? handle.execute("ROLLBACK")
            throw error
        }
        pending = []
        loadedFilemtime = try? databaseURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        try reloadPage()
    }

    public func closeDecision() -> CloseDecision {
        isDirty ? .prompt(changeCount: pending.count) : .proceed
    }

    public func runSQL(_ sql: String, cursor: Int, runAll: Bool) async throws -> QueryResult {
        let statements = runAll ? SQLStatements.split(sql) : [SQLStatements.current(in: sql, cursor: cursor)]
        var sets: [QueryResultSet] = []
        for statement in statements {
            if QuerySafety.isWrite(statement) {
                if safeMode {
                    throw TableFlipError.needsConfirmation
                }
                try handle.execute(statement)
                queryHistory.append(QueryHistoryItem(sql: statement))
                continue
            }
            let capped = QuerySafety.cappedSelect(statement, cap: 1000)
            let result = try handle.query(capped)
            sets.append(result)
            queryHistory.append(QueryHistoryItem(sql: statement))
        }
        objects = try SQLiteSchema.objects(handle)
        return QueryResult(sets: sets)
    }

    public func structure(of table: String) async throws -> [Column] {
        try SQLiteSchema.columns(handle, table: table)
    }

    public func setHiddenColumns(_ columns: [String]) {
        guard let currentTable else { return }
        hiddenColumnsByTable[currentTable] = columns
    }

    public func findInPage(_ needle: String) -> [Int] {
        let lowered = needle.lowercased()
        guard !lowered.isEmpty else { return [] }
        return loadedRows.enumerated().compactMap { index, row in
            row.values.values.contains { value in
                if case .text(let text) = value {
                    return text.lowercased().contains(lowered)
                }
                return false
            } ? index : nil
        }
    }

    public func exportCurrentPage(format: String) throws -> String {
        let names = currentColumns.map(\.name)
        let rows = loadedRows.map { row in names.map { row.values[$0] ?? .null } }
        switch format {
        case "json": return CopyFormat.json(columns: names, rows: rows)
        case "sql": return CopyFormat.sqlInsert(table: currentTable ?? "table", columns: names, rows: rows, dialect: .sqlite)
        default: return CopyFormat.csv(columns: names, rows: rows) + "\n"
        }
    }

    public func stageImportedCSV(_ csv: String) throws {
        try ensureEditable()
        let table = try CSVImport.parse(csv, hasHeader: true)
        for record in table.records {
            _ = stageInsert(values: record)
        }
    }

    private func reloadPage() throws {
        guard let currentTable else {
            loadedRows = []
            return
        }
        let whereClause = FilterSQL.whereClause(filters, dialect: .sqlite)
        var sql = "SELECT \(currentColumns.map { Identifier.quote($0.name, dialect: .sqlite) }.joined(separator: ", ")) FROM \(Identifier.quote(currentTable, dialect: .sqlite))"
        if !whereClause.sql.isEmpty {
            sql += " WHERE \(whereClause.sql)"
        }
        if let sort {
            let direction = sort.direction == .descending ? "DESC" : "ASC"
            sql += " ORDER BY \(Identifier.quote(sort.column, dialect: .sqlite)) \(direction)"
        } else if let pk = currentColumns.first(where: \.isPrimaryKey) {
            sql += " ORDER BY \(Identifier.quote(pk.name, dialect: .sqlite))"
        }
        sql += " LIMIT \(pageSize) OFFSET \(offset)"
        let result = try handle.query(sql, parameters: whereClause.parameters)
        let countSQL: String
        if whereClause.sql.isEmpty {
            countSQL = "SELECT COUNT(*) FROM \(Identifier.quote(currentTable, dialect: .sqlite))"
        } else {
            countSQL = "SELECT COUNT(*) FROM \(Identifier.quote(currentTable, dialect: .sqlite)) WHERE \(whereClause.sql)"
        }
        let countResult = try handle.query(countSQL, parameters: whereClause.parameters)
        if case .integer(let count) = countResult.rows.first?.first {
            totalCount = Int(count)
        } else {
            totalCount = result.rows.count
        }
        let pkNames = currentColumns.filter(\.isPrimaryKey).map(\.name)
        loadedRows = result.rows.map { row in
            var values: [String: CellValue] = [:]
            for (index, column) in currentColumns.enumerated() where index < row.count {
                values[column.name] = row[index]
            }
            var identity: [String: CellValue] = [:]
            for name in pkNames {
                identity[name] = values[name] ?? .null
            }
            return GridRow(identity: identity, values: values, state: .clean)
        }
        applyPendingOverlay()
    }

    private func applyPendingOverlay() {
        for change in pending {
            switch change {
            case .update(let identity, let set):
                if let index = loadedRows.firstIndex(where: { $0.identity == identity }) {
                    for (column, value) in set {
                        loadedRows[index].values[column] = value
                    }
                    loadedRows[index].state = .updated
                }
            case .delete(let identity):
                if let index = loadedRows.firstIndex(where: { $0.identity == identity }) {
                    loadedRows[index].state = .pendingDelete
                }
            case .insert(let values):
                if !loadedRows.contains(where: { $0.state == .pendingInsert && $0.values == values }) {
                    loadedRows.append(GridRow(identity: [:], values: values, state: .pendingInsert))
                }
            }
        }
    }

    private func rewriteInsert(at rowIndex: Int) {
        let values = loadedRows[rowIndex].values
        var insertIndex = 0
        for (pendingIndex, change) in pending.enumerated() {
            if case .insert = change {
                if pendingInsertRowIndex(insertIndex) == rowIndex {
                    pending[pendingIndex] = .insert(values)
                    return
                }
                insertIndex += 1
            }
        }
    }

    private func pendingInsertRowIndex(_ nth: Int) -> Int? {
        var count = 0
        for (index, row) in loadedRows.enumerated() where row.state == .pendingInsert {
            if count == nth { return index }
            count += 1
        }
        return nil
    }

    private func rewritePendingInserts() {
        pending.removeAll {
            if case .insert = $0 { return true }
            return false
        }
        for row in loadedRows where row.state == .pendingInsert {
            pending.append(.insert(row.values))
        }
    }

    private func ensureEditable() throws {
        if isReadOnly { throw TableFlipError.readOnly }
        if !canEditRows { throw TableFlipError.notEditable }
    }

    private func warnIfFileChanged() throws {
        let current = try? databaseURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        if let loadedFilemtime, let current, current > loadedFilemtime.addingTimeInterval(0.5), pending.contains(where: {
            if case .insert = $0 { return false }
            return true
        }) {
            throw TableFlipError.engine("This file has changed on disk since it was opened. Reload before committing.")
        }
    }
}
