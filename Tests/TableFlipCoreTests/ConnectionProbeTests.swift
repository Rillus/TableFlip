import Testing
@testable import TableFlipCore

@Test("O-7 Test Connection fails quickly against a closed local port")
func probeClosedPort() {
    #expect(!ConnectionProbe.tcp(host: "127.0.0.1", port: 1))
}
