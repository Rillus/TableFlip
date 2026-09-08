import SwiftUI
import TableFlipCore
import UniformTypeIdentifiers

struct WelcomeView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TableFlip")
                    .font(.largeTitle.weight(.semibold))
                Text("Open a SQLite file, or connect to Postgres or MySQL on this Mac.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Open Database File…") { openFiles() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("New SQLite Database…") { createFile() }
                Button("New Connection…") { store.showNewConnection = true }
            }

            recentsList

            if let welcomeError = store.welcomeError {
                Text(welcomeError)
                    .foregroundStyle(.red)
            }

            Spacer()
            Text("Free and unrestricted. Changes are not saved until you press Commit (⌘S).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .onReceive(NotificationCenter.default.publisher(for: .tableFlipOpenFile)) { _ in
            openFiles()
        }
        .sheet(isPresented: $store.showNewConnection) {
            NewConnectionSheet { url in
                openWindow(id: "workspace", value: url)
            }
        }
    }

    @ViewBuilder
    private var recentsList: some View {
        if store.recents.items.isEmpty {
            ContentUnavailableView(
                "Open a SQLite file to get started.",
                systemImage: "cylinder.split.1x2",
                description: Text("Recent databases will appear here.")
            )
            .frame(maxHeight: 220)
        } else {
            List(store.recents.items, id: \.path) { item in
                HStack {
                    Image(systemName: item.isAvailable ? "cylinder" : "exclamationmark.triangle")
                    VStack(alignment: .leading) {
                        Text(item.displayName)
                        Text(item.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !item.isAvailable {
                        Text("Unavailable")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if item.isAvailable {
                        openWindow(id: "workspace", value: URL(fileURLWithPath: item.path))
                    }
                }
            }
            .frame(minHeight: 180)
        }
    }

    private func openFiles() {
        for url in store.chooseFiles() {
            store.recents.remember(.sqliteFile(path: url.path))
            openWindow(id: "workspace", value: url)
        }
    }

    private func createFile() {
        guard let url = store.chooseNewDatabase() else { return }
        Task {
            do {
                _ = try await Workspace.createSQLite(at: url)
                store.recents.remember(.sqliteFile(path: url.path))
                openWindow(id: "workspace", value: url)
            } catch {
                store.welcomeError = (error as? TableFlipError)?.publicMessage ?? error.localizedDescription
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    store.recents.remember(.sqliteFile(path: url.path))
                    openWindow(id: "workspace", value: url)
                }
            }
        }
        return true
    }
}
