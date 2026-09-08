import Testing
@testable import TableFlipCore

@Test("N-5 Open Anything fuzzy-matches table names")
func openAnythingRanksMatches() {
    let objects = [
        DatabaseObject(kind: .table, schema: "public", name: "orders"),
        DatabaseObject(kind: .view, schema: "public", name: "active_orders"),
        DatabaseObject(kind: .table, schema: "public", name: "users"),
    ]
    let hits = OpenAnything.search("ord", in: objects)
    #expect(hits.map(\.name) == ["orders", "active_orders"])
}

@Test("N-3 sidebar search is case-insensitive contains")
func sidebarFilter() {
    let objects = [
        DatabaseObject(kind: .table, schema: nil, name: "Users"),
        DatabaseObject(kind: .table, schema: nil, name: "orders"),
    ]
    #expect(SidebarSearch.filter(objects, query: "use").map(\.name) == ["Users"])
    #expect(SidebarSearch.filter(objects, query: "").count == 2)
}
