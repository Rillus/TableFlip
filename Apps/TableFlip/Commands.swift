import SwiftUI

extension TableFlipApp {
    @CommandsBuilder
    var tableFlipCommands: some Commands {
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
            Button("Run Query") {
                NotificationCenter.default.post(name: .tableFlipRunQuery, object: nil)
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}

extension Notification.Name {
    static let tableFlipOpenFile = Notification.Name("tableFlipOpenFile")
    static let tableFlipCommit = Notification.Name("tableFlipCommit")
    static let tableFlipRunQuery = Notification.Name("tableFlipRunQuery")
}
