import SwiftUI
import TableFlipCore

@Observable
final class WorkspaceSession {
    let databaseURL: URL
    var workspace: Workspace?
    var errorMessage: String?
    var selectedTable: String?
    var sidebarQuery = ""
    var page: GridPage?
    var filters: [RowFilter] = [RowFilter(column: "", op: .contains, value: "")]
    var showFilters = false
    var showQuery = false
    var showInspector = false
    var showOpenAnything = false
    var showCommitSheet = false
    var showStructure = false
    var sql = "SELECT * FROM sqlite_master LIMIT 50;"
    var queryResult: QueryResult?
    var selectedRow: Int?
    var openAnythingQuery = ""
    var infoBanner: String?

    var objects: [DatabaseObject] {
        SidebarSearch.filter(workspace?.objects ?? [], query: sidebarQuery)
    }

    var isDirty: Bool { workspace?.isDirty == true }
    var isReadOnly: Bool { workspace?.isReadOnly == true }
    var canEdit: Bool { workspace?.canEditRows == true }
    var previewSQL: String { workspace?.previewSQL ?? "" }
    var statusText: String {
        guard let page else { return "No table selected" }
        let start = page.rows.isEmpty ? 0 : page.offset + 1
        let end = page.offset + page.rows.count
        return "Showing \(start)–\(end) of \(page.totalCount)"
    }

    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    func load() async {
        do {
            let opened = try await Workspace.openSQLite(at: databaseURL)
            workspace = opened
            if opened.isReadOnly {
                infoBanner = "This database is read-only, so changes can’t be committed."
            }
            if let first = opened.objects.first(where: { $0.kind == .table }) ?? opened.objects.first {
                try await select(table: first.name)
            }
        } catch {
            errorMessage = (error as? TableFlipError)?.publicMessage ?? error.localizedDescription
        }
    }

    func select(table: String) async throws {
        selectedTable = table
        try await workspace?.selectTable(table)
        page = try await workspace?.currentPage()
        selectedRow = nil
        if let columns = page?.columns, let first = columns.first, filters.first?.column.isEmpty == true {
            filters[0].column = first.name
        }
    }

    func reload() async {
        do {
            page = try await workspace?.currentPage()
        } catch {
            errorMessage = (error as? TableFlipError)?.publicMessage ?? error.localizedDescription
        }
    }

    func applyFilters() async {
        do {
            let active = filters.filter { !$0.column.isEmpty && ($0.op == .isNull || $0.op == .isNotNull || !$0.value.isEmpty) }
            try await workspace?.applyFilters(active)
            await reload()
        } catch {
            errorMessage = (error as? TableFlipError)?.publicMessage ?? error.localizedDescription
        }
    }

    func commit() async {
        do {
            try await workspace?.commit()
            showCommitSheet = false
            await reload()
        } catch {
            errorMessage = (error as? TableFlipError)?.publicMessage ?? error.localizedDescription
        }
    }

    func runSQL() async {
        do {
            queryResult = try await workspace?.runSQL(sql, cursor: sql.count, runAll: false)
        } catch {
            errorMessage = (error as? TableFlipError)?.publicMessage ?? error.localizedDescription
        }
    }
}

struct WorkspaceScreen: View {
    let databaseURL: URL
    @Environment(SessionStore.self) private var store
    @State private var session: WorkspaceSession
    @Environment(\.dismiss) private var dismiss

    init(databaseURL: URL) {
        self.databaseURL = databaseURL
        _session = State(initialValue: WorkspaceSession(databaseURL: databaseURL))
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                if session.showQuery {
                    QueryEditorView(session: session)
                        .frame(minHeight: 160)
                    Divider()
                }
                if session.showStructure {
                    StructureView(session: session)
                } else {
                    DataGridView(session: session)
                }
                if session.showFilters {
                    FilterBar(session: session)
                }
                statusBar
            }
        }
        .navigationTitle(databaseURL.lastPathComponent)
        .task {
            await session.load()
            try? await session.workspace?.setPageSize(store.preferences.pageSize)
            await session.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tableFlipCommit)) { _ in
            session.showCommitSheet = true
        }
        .alert("Couldn’t open database", isPresented: Binding(
            get: { session.errorMessage != nil && session.workspace == nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.errorMessage ?? "")
        }
        .sheet(isPresented: $session.showCommitSheet) {
            CommitSheet(session: session)
        }
        .sheet(isPresented: $session.showOpenAnything) {
            OpenAnythingSheet(session: session)
        }
        .onAppear {
            store.recents.remember(.sqliteFile(path: databaseURL.path))
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            TextField("Filter tables", text: $session.sidebarQuery)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            List(session.objects, id: \.name, selection: $session.selectedTable) { object in
                Label(object.name, systemImage: object.kind == .view ? "eye" : "tablecells")
                    .tag(object.name)
            }
            .onChange(of: session.selectedTable) { _, name in
                guard let name else { return }
                Task { try? await session.select(table: name) }
            }
        }
        .frame(minWidth: 200)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button("Commit") { session.showCommitSheet = true }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!session.isDirty || session.isReadOnly)
            Button("Discard") { session.workspace?.discard(); Task { await session.reload() } }
                .disabled(!session.isDirty)
            Button("Preview") { session.showCommitSheet = true }
                .disabled(!session.isDirty)
            Toggle("Safe", isOn: Binding(
                get: { session.workspace?.safeMode ?? false },
                set: { session.workspace?.safeMode = $0 }
            ))
            .toggleStyle(.checkbox)
            Divider()
            Button("Query") { session.showQuery.toggle() }
                .keyboardShortcut("e", modifiers: .command)
            Button("Open Anything") { session.showOpenAnything = true }
                .keyboardShortcut("p", modifiers: .command)
            Button("Structure") { session.showStructure.toggle() }
            Spacer()
            Button("+ Row") {
                _ = session.workspace?.stageInsert(values: [:])
                Task { await session.reload() }
            }
            .disabled(!session.canEdit)
            Button("Duplicate") {
                if let selectedRow = session.selectedRow {
                    try? session.workspace?.stageDuplicate(rowIndex: selectedRow)
                    Task { await session.reload() }
                }
            }
            .disabled(!session.canEdit)
            Button("Delete") {
                if let selectedRow = session.selectedRow {
                    try? session.workspace?.stageDelete(rowIndexes: [selectedRow])
                    Task { await session.reload() }
                }
            }
            .disabled(!session.canEdit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusBar: some View {
        HStack {
            if session.isDirty {
                Label("Edited", systemImage: "pencil.circle.fill")
                    .foregroundStyle(.orange)
            }
            if session.workspace?.safeMode == true {
                Label("Safe mode", systemImage: "lock.fill")
            }
            Text(session.statusText)
            Spacer()
            Button("Filters") { session.showFilters.toggle() }
                .keyboardShortcut("f", modifiers: .command)
            Button("Inspector") { session.showInspector.toggle() }
            if let errorMessage = session.errorMessage, session.workspace != nil {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
