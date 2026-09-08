import AppKit
import Foundation
import SwiftUI
import TableFlipCore
import UniformTypeIdentifiers

@Observable
final class SessionStore {
    var recents: RecentsStore
    var preferences: PreferencesStore
    var connections: ConnectionStore
    var showNewConnection = false
    var welcomeError: String?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TableFlip", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("TableFlip")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        recents = RecentsStore(fileURL: support.appendingPathComponent("recents.json"))
        preferences = PreferencesStore(fileURL: support.appendingPathComponent("preferences.json"))
        connections = ConnectionStore(
            fileURL: support.appendingPathComponent("connections.json"),
            secrets: KeychainSecretStore()
        )
    }

    func chooseFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.item]
        panel.allowsOtherFileTypes = true
        panel.message = "Choose a SQLite database"
        return panel.runModal() == .OK ? panel.urls : []
    }

    func chooseNewDatabase() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlite") ?? .data]
        panel.nameFieldStringValue = "untitled.sqlite"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
