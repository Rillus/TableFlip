import Foundation
import Testing
@testable import TableFlipCore

@Test("O-9 saved connections never persist passwords in the JSON file")
func connectionStoreHidesPasswords() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let secrets = InMemorySecretStore()
    let store = ConnectionStore(fileURL: directory.appendingPathComponent("connections.json"), secrets: secrets)
    var config = ConnectionConfig(
        engine: .postgres,
        host: "127.0.0.1",
        port: 5432,
        username: "ada",
        password: "s3cret",
        database: "app"
    )
    let id = try store.save(config, name: "Local Postgres")
    let json = try String(contentsOf: directory.appendingPathComponent("connections.json"), encoding: .utf8)
    #expect(!json.contains("s3cret"))
    #expect(secrets.password(for: id) == "s3cret")
    let loaded = try store.load(id)
    #expect(loaded.password == "s3cret")
    #expect(HostLocality.isLocal(loaded.host ?? ""))
    config.host = "db.example.com"
    #expect(!HostLocality.isLocal(config.host ?? ""))
}

@Test("A-2 preferences persist page size and confirm-on-commit")
func preferencesRoundTrip() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("prefs-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    var prefs = PreferencesStore(fileURL: url)
    prefs.pageSize = 300
    prefs.confirmOnCommit = true
    prefs.gridFontSize = 13
    prefs.save()
    let loaded = PreferencesStore(fileURL: url)
    #expect(loaded.pageSize == 300)
    #expect(loaded.confirmOnCommit)
    #expect(loaded.gridFontSize == 13)
}
