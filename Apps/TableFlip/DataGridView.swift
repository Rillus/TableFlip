import AppKit
import SwiftUI
import TableFlipCore

struct DataGridView: View {
    @Bindable var session: WorkspaceSession

    var body: some View {
        Group {
            if let error = session.errorMessage, session.workspace == nil {
                ContentUnavailableView("Couldn’t open this file", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if session.page == nil {
                ContentUnavailableView("Select a table", systemImage: "tablecells")
            } else if let page = session.page, page.rows.isEmpty {
                ContentUnavailableView {
                    Label("This table has no rows.", systemImage: "tray")
                } description: {
                    Text("Add a row, or unset filters if you were searching.")
                } actions: {
                    Button("Add row") {
                        _ = session.workspace?.stageInsert(values: [:])
                        Task { await session.reload() }
                    }
                    .disabled(!(session.canEdit))
                    if session.showFilters {
                        Button("Unset filters") {
                            Task {
                                try? await session.workspace?.unsetFilters()
                                await session.reload()
                            }
                        }
                    }
                }
            } else if let page = session.page {
                ScrollView([.horizontal, .vertical]) {
                    grid(page)
                }
            }
        }
        .inspector(isPresented: $session.showInspector) {
            InspectorView(session: session)
                .frame(minWidth: 260)
        }
    }

    private func grid(_ page: GridPage) -> some View {
        let visible = page.columns.filter { !(session.workspace?.hiddenColumns.contains($0.name) ?? false) }
        return Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(visible, id: \.name) { column in
                    Button(column.name) {
                        Task { try? await session.workspace?.cycleSort(column: column.name); await session.reload() }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .padding(8)
                    .frame(minWidth: 120, alignment: .leading)
                    .background(.quaternary)
                    .help(column.declaredType)
                }
            }
            ForEach(Array(page.rows.enumerated()), id: \.offset) { index, row in
                GridRow {
                    ForEach(visible, id: \.name) { column in
                        CellView(
                            value: row.values[column.name] ?? .null,
                            state: row.state,
                            isSelected: session.selectedRow == index
                        ) { newValue in
                            try? session.workspace?.stageEdit(rowIndex: index, column: column.name, value: newValue)
                            Task { await session.reload() }
                        }
                        .onTapGesture { session.selectedRow = index }
                    }
                }
            }
        }
        .padding(8)
    }
}

struct CellView: View {
    let value: CellValue
    let state: RowState
    let isSelected: Bool
    var onCommit: (CellValue) -> Void
    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        Group {
            if editing {
                TextField("", text: $draft)
                    .onSubmit { submit() }
                    .textFieldStyle(.plain)
            } else {
                Text(display)
                    .italic(isNull)
                    .foregroundStyle(isNull ? .secondary : .primary)
            }
        }
        .padding(8)
        .frame(minWidth: 120, alignment: .leading)
        .background(background)
        .strikethrough(state == .pendingDelete)
        .onTapGesture(count: 2) {
            draft = isNull ? "" : raw
            editing = true
        }
        .contextMenu {
            Button("Set NULL") { onCommit(.null) }
            Button("Copy") { copy() }
        }
    }

    private var isNull: Bool {
        if case .null = value { return true }
        return false
    }

    private var display: String {
        switch value {
        case .null: return "NULL"
        case .integer(let number): return String(number)
        case .double(let number): return String(number)
        case .text(let text):
            if text.hasPrefix("{") || text.hasPrefix("[") {
                return String(text.prefix(40)) + (text.count > 40 ? "…" : "")
            }
            return text
        case .blob: return "<blob>"
        }
    }

    private var raw: String {
        switch value {
        case .null: return ""
        case .integer(let number): return String(number)
        case .double(let number): return String(number)
        case .text(let text): return text
        case .blob: return ""
        }
    }

    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.12) }
        switch state {
        case .updated: return Color.orange.opacity(0.18)
        case .pendingInsert: return Color.green.opacity(0.18)
        case .pendingDelete: return Color.red.opacity(0.18)
        case .clean: return Color.clear
        }
    }

    private func submit() {
        editing = false
        if draft.isEmpty && isNull { return }
        if let number = Int64(draft) {
            onCommit(.integer(number))
        } else {
            onCommit(.text(draft))
        }
    }

    private func copy() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(display, forType: .string)
        #endif
    }
}
