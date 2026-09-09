public enum OpenAnything {
    public static func search(_ query: String, in objects: [DatabaseObject]) -> [DatabaseObject] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return objects }
        let matches = objects.filter { $0.name.lowercased().contains(needle) }
        return matches.sorted { lhs, rhs in
            let lPrefix = lhs.name.lowercased().hasPrefix(needle)
            let rPrefix = rhs.name.lowercased().hasPrefix(needle)
            if lPrefix != rPrefix { return lPrefix }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

public enum SidebarSearch {
    public static func filter(_ objects: [DatabaseObject], query: String) -> [DatabaseObject] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return objects }
        return objects.filter { $0.name.localizedCaseInsensitiveContains(needle) }
    }
}
