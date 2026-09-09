import SwiftUI
import TableFlipCore

@main
struct TableFlipApp: App {
    @State private var sessionStore = SessionStore()

    var body: some Scene {
        Window("TableFlip", id: "welcome") {
            WelcomeView()
                .environment(sessionStore)
                .frame(minWidth: 640, minHeight: 420)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Database File…") {
                    NotificationCenter.default.post(name: .tableFlipOpenFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Database") {
                Button("Commit Changes") {
                    NotificationCenter.default.post(name: .tableFlipCommit, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }

        WindowGroup(id: "workspace", for: URL.self) { $url in
            if let url {
                WorkspaceScreen(databaseURL: url)
                    .environment(sessionStore)
            } else {
                Text("Open a database to get started.")
                    .foregroundStyle(.secondary)
            }
        }
        .defaultSize(width: 1100, height: 720)

        Settings {
            PreferencesView()
                .environment(sessionStore)
        }
    }
}
