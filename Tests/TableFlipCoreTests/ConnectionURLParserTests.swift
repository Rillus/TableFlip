import Testing
@testable import TableFlipCore

@Test("O-10 parses postgresql URLs including defaults")
func parsePostgresURL() throws {
    let config = try ConnectionURLParser.parse("postgresql://ada@127.0.0.1/app")
    #expect(config.engine == .postgres)
    #expect(config.host == "127.0.0.1")
    #expect(config.port == 5432)
    #expect(config.username == "ada")
    #expect(config.database == "app")
    #expect(config.password == nil)
}

@Test("O-10 parses mysql URLs with password and port")
func parseMySQLURL() throws {
    let config = try ConnectionURLParser.parse("mysql://root:secret@localhost:3307/shop")
    #expect(config.engine == .mysql)
    #expect(config.host == "localhost")
    #expect(config.port == 3307)
    #expect(config.username == "root")
    #expect(config.password == "secret")
    #expect(config.database == "shop")
}

@Test("O-10 parses sqlite file URLs")
func parseSQLiteURL() throws {
    let config = try ConnectionURLParser.parse("sqlite:////tmp/app.sqlite")
    #expect(config.engine == .sqlite)
    #expect(config.filePath == "/tmp/app.sqlite")
}

@Test("S-5 localhost variants are local; others are remote")
func hostLocality() {
    #expect(HostLocality.isLocal("localhost"))
    #expect(HostLocality.isLocal("127.0.0.1"))
    #expect(HostLocality.isLocal("::1"))
    #expect(!HostLocality.isLocal("db.example.com"))
    #expect(!HostLocality.isLocal("8.8.8.8"))
}
