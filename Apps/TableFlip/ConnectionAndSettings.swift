import SwiftUI
import TableFlipCore

struct NewConnectionSheet: View {
    var onOpenSQLite: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var store

    @State private var engine: EngineKind = .postgres
    @State private var host = "127.0.0.1"
    @State private var port = "5432"
    @State private var username = ""
    @State private var password = ""
    @State private var database = ""
    @State private var urlText = ""
    @State private var error: String?
    @State private var name = "Local database"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Connection")
                .font(.title2)
            Text("v1 stores the connection and password in Keychain. Opening a live Postgres or MySQL session from this sheet lands in a later build; SQLite files still open immediately.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Engine", selection: $engine) {
                Text("PostgreSQL").tag(EngineKind.postgres)
                Text("MySQL").tag(EngineKind.mysql)
                Text("MariaDB").tag(EngineKind.mariaDB)
                Text("SQLite file").tag(EngineKind.sqlite)
            }

            TextField("Paste URL", text: $urlText)
                .onSubmit(applyURL)

            if engine != .sqlite {
                TextField("Host", text: $host)
                TextField("Port", text: $port)
                TextField("User", text: $username)
                SecureField("Password", text: $password)
                TextField("Database", text: $database)
                if !HostLocality.isLocal(host) {
                    Label("Remote host — this is not a local database.", systemImage: "network")
                        .foregroundStyle(.orange)
                }
            }

            TextField("Name", text: $name)

            if let error {
                Text(error).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Test Connection") { testConnection() }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
        .onChange(of: engine) { _, newValue in
            if newValue == .mysql || newValue == .mariaDB { port = "3306" }
            if newValue == .postgres { port = "5432" }
        }
    }

    private func testConnection() {
        guard let portNumber = Int(port) else {
            error = "Port must be a number."
            return
        }
        error = ConnectionProbe.tcp(host: host, port: portNumber)
            ? "Connected to \(host):\(portNumber)."
            : "Could not open \(host):\(portNumber). Is the server running?"
    }

    private func applyURL() {
        do {
            let config = try ConnectionURLParser.parse(urlText)
            engine = config.engine
            host = config.host ?? host
            if let configPort = config.port { port = String(configPort) }
            username = config.username ?? username
            password = config.password ?? password
            database = config.database ?? database
            if let path = config.filePath {
                onOpenSQLite(URL(fileURLWithPath: path))
                dismiss()
            }
        } catch {
            self.error = (error as? TableFlipError)?.publicMessage ?? error.localizedDescription
        }
    }

    private func save() {
        let config = ConnectionConfig(
            engine: engine,
            host: host,
            port: Int(port),
            username: username,
            password: password.isEmpty ? nil : password,
            database: database.isEmpty ? nil : database
        )
        do {
            _ = try store.connections.save(config, name: name)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct PreferencesView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        Form {
            Picker("Rows per page", selection: Binding(
                get: { store.preferences.pageSize },
                set: { store.preferences.pageSize = $0; store.preferences.save() }
            )) {
                Text("50").tag(50)
                Text("100").tag(100)
                Text("300").tag(300)
                Text("1000").tag(1000)
            }
            Toggle("Confirm before Commit", isOn: Binding(
                get: { store.preferences.confirmOnCommit },
                set: { store.preferences.confirmOnCommit = $0; store.preferences.save() }
            ))
        }
        .padding(20)
        .frame(width: 360)
    }
}
