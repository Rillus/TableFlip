import Foundation

public enum SQLStatements {
    public static func split(_ sql: String) -> [String] {
        var statements: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var iterator = sql.makeIterator()
        while let character = iterator.next() {
            if character == "'" && !inDouble {
                inSingle.toggle()
                current.append(character)
            } else if character == "\"" && !inSingle {
                inDouble.toggle()
                current.append(character)
            } else if character == ";" && !inSingle && !inDouble {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    statements.append(trimmed)
                }
                current = ""
            } else {
                current.append(character)
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            statements.append(trimmed)
        }
        return statements
    }

    public static func current(in sql: String, cursor: Int) -> String {
        let statements = splitKeepingRanges(sql)
        let index = min(max(cursor, 0), sql.count)
        if let match = statements.first(where: { $0.range.contains(index) }) {
            return match.sql
        }
        return statements.last?.sql ?? sql.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Marked {
        var sql: String
        var range: Range<Int>
    }

    private static func splitKeepingRanges(_ sql: String) -> [Marked] {
        var result: [Marked] = []
        var current = ""
        var start = 0
        var index = 0
        var inSingle = false
        var inDouble = false
        for character in sql {
            if character == "'" && !inDouble {
                inSingle.toggle()
                current.append(character)
            } else if character == "\"" && !inSingle {
                inDouble.toggle()
                current.append(character)
            } else if character == ";" && !inSingle && !inDouble {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append(Marked(sql: trimmed, range: start..<(index + 1)))
                }
                current = ""
                start = index + 1
            } else {
                current.append(character)
            }
            index += 1
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result.append(Marked(sql: trimmed, range: start..<sql.count))
        }
        return result
    }
}

public enum QuerySafety {
    public static func cappedSelect(_ sql: String, cap: Int) -> String {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSelectLike(trimmed), !hasLimit(trimmed) else { return trimmed }
        return "\(trimmed) LIMIT \(cap)"
    }

    public static func isWrite(_ sql: String) -> Bool {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let keyword = firstKeyword(trimmed) else { return false }
        if keyword == "EXPLAIN" { return false }
        return ["INSERT", "UPDATE", "DELETE", "REPLACE", "CREATE", "DROP", "ALTER", "TRUNCATE", "GRANT", "REVOKE", "VACUUM", "REINDEX", "ATTACH", "DETACH"].contains(keyword)
    }

    public static func isSelectLike(_ sql: String) -> Bool {
        let keyword = firstKeyword(sql) ?? ""
        return ["SELECT", "WITH", "VALUES", "SHOW", "PRAGMA", "EXPLAIN"].contains(keyword)
    }

    private static func hasLimit(_ sql: String) -> Bool {
        sql.range(of: "\\bLIMIT\\b", options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func firstKeyword(_ sql: String) -> String? {
        let scalars = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var keyword = ""
        for character in scalars {
            if character.isLetter {
                keyword.append(character)
            } else if keyword.isEmpty {
                continue
            } else {
                break
            }
        }
        return keyword.isEmpty ? nil : keyword
    }
}
