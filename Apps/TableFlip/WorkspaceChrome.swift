import SwiftUI
import TableFlipCore

struct FilterBar: View {
    @Bindable var session: WorkspaceSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(session.filters.indices, id: \.self) { index in
                HStack {
                    Picker("Column", selection: $session.filters[index].column) {
                        ForEach(session.page?.columns ?? [], id: \.name) { column in
                            Text(column.name).tag(column.name)
                        }
                    }
                    .labelsHidden()
                    Picker("Operator", selection: $session.filters[index].op) {
                        Text("equals").tag(FilterOperator.equal)
                        Text("not equal").tag(FilterOperator.notEqual)
                        Text("contains").tag(FilterOperator.contains)
                        Text("starts with").tag(FilterOperator.startsWith)
                        Text("greater than").tag(FilterOperator.greaterThan)
                        Text("less than").tag(FilterOperator.lessThan)
                        Text("is null").tag(FilterOperator.isNull)
                        Text("is not null").tag(FilterOperator.isNotNull)
                    }
                    .labelsHidden()
                    if session.filters[index].op != .isNull && session.filters[index].op != .isNotNull {
                        TextField("Value", text: $session.filters[index].value)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { Task { await session.applyFilters() } }
                    }
                    Button("+") {
                        let column = session.page?.columns.first?.name ?? ""
                        session.filters.append(RowFilter(column: column, op: .contains, value: ""))
                    }
                    Button("−") {
                        if session.filters.count > 1 {
                            session.filters.remove(at: index)
                        }
                    }
                }
            }
            HStack {
                Button("Apply") { Task { await session.applyFilters() } }
                Button("Unset") {
                    Task {
                        try? await session.workspace?.unsetFilters()
                        await session.reload()
                    }
                }
                Text(session.workspace?.generatedWhereSQL.sql ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(8)
        .background(.bar)
    }
}

struct QueryEditorView: View {
    @Bindable var session: WorkspaceSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SQL")
                    .font(.headline)
                Spacer()
                Button("Run current") { Task { await session.runSQL() } }
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(8)
            TextEditor(text: $session.sql)
                .font(.system(.body, design: .monospaced))
                .padding(4)
            if let result = session.queryResult {
                Text("\(result.sets.first?.rows.count ?? 0) rows")
                    .font(.caption)
                    .padding(.horizontal, 8)
            }
        }
    }
}

struct StructureView: View {
    var session: WorkspaceSession
    @State private var columns: [Column] = []

    var body: some View {
        Table(columns) {
            TableColumn("Name", value: \.name)
            TableColumn("Type", value: \.declaredType)
            TableColumn("Nullable") { column in Text(column.isNullable ? "Yes" : "No") }
            TableColumn("Primary") { column in Text(column.isPrimaryKey ? "Yes" : "") }
        }
        .task(id: session.selectedTable) {
            if let name = session.selectedTable {
                columns = (try? await session.workspace?.structure(of: name)) ?? []
            }
        }
    }
}

struct InspectorView: View {
    @Bindable var session: WorkspaceSession

    var body: some View {
        if let page = session.page, let index = session.selectedRow, page.rows.indices.contains(index) {
            let row = page.rows[index]
            Form {
                ForEach(page.columns, id: \.name) { column in
                    LabeledContent(column.name) {
                        Text(display(row.values[column.name] ?? .null))
                    }
                }
            }
            .padding()
        } else {
            ContentUnavailableView("Select a row", systemImage: "sidebar.right")
        }
    }

    private func display(_ value: CellValue) -> String {
        switch value {
        case .null: return "NULL"
        case .integer(let number): return String(number)
        case .double(let number): return String(number)
        case .text(let text): return text
        case .blob: return "<blob>"
        }
    }
}

struct CommitSheet: View {
    var session: WorkspaceSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review changes")
                .font(.title2)
            Text("These statements will run in a single transaction.")
                .foregroundStyle(.secondary)
            ScrollView {
                Text(session.previewSQL.isEmpty ? "No pending changes." : session.previewSQL)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Commit") { Task { await session.commit() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(session.previewSQL.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 280)
    }
}

struct OpenAnythingSheet: View {
    @Bindable var session: WorkspaceSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Open a table or view", text: $session.openAnythingQuery)
                .textFieldStyle(.roundedBorder)
            List(OpenAnything.search(session.openAnythingQuery, in: session.workspace?.objects ?? []), id: \.name) { object in
                Button(object.name) {
                    Task {
                        try? await session.select(table: object.name)
                        dismiss()
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 360, minHeight: 280)
    }
}
