import Foundation

public enum CopyFormat {
    public static func tsv(columns: [String], rows: [[CellValue]]) -> String {
        rows.map { row in
            zip(columns, row).map { _, value in tsvValue(value) }.joined(separator: "\t")
        }.joined(separator: "\n")
    }

    public static func csv(columns: [String], rows: [[CellValue]]) -> String {
        CSVExport.serialize(columns: columns, rows: rows).trimmingCharacters(in: .newlines)
    }

    public static func json(columns: [String], rows: [[CellValue]]) -> String {
        let objects: [[String: Any]] = rows.map { row in
            var object: [String: Any] = [:]
            for (column, value) in zip(columns, row) {
                object[column] = jsonValue(value)
            }
            return object
        }
        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: []),
              let text = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return text
    }

    public static func markdown(columns: [String], rows: [[CellValue]]) -> String {
        let header = "| " + columns.joined(separator: " | ") + " |"
        let divider = "| " + columns.map { _ in "---" }.joined(separator: " | ") + " |"
        let body = rows.map { row in
            "| " + zip(columns, row).map { _, value in display(value) }.joined(separator: " | ") + " |"
        }
        return ([header, divider] + body).joined(separator: "\n")
    }

    public static func sqlInsert(table: String, columns: [String], rows: [[CellValue]], dialect: SQLDialect) -> String {
        rows.map { row in
            let values = row.map(MutationSQL.literal).joined(separator: ", ")
            let quoted = columns.map { Identifier.quote($0, dialect: dialect) }.joined(separator: ", ")
            return "INSERT INTO \(Identifier.quote(table, dialect: dialect)) (\(quoted)) VALUES (\(values));"
        }.joined(separator: "\n")
    }

    private static func tsvValue(_ value: CellValue) -> String {
        switch value {
        case .null: return "\\N"
        case .integer(let number): return String(number)
        case .double(let number): return String(number)
        case .text(let text): return text.replacingOccurrences(of: "\t", with: " ")
        case .blob: return "<blob>"
        }
    }

    private static func display(_ value: CellValue) -> String {
        switch value {
        case .null: return "NULL"
        case .integer(let number): return String(number)
        case .double(let number): return String(number)
        case .text(let text): return text
        case .blob: return "<blob>"
        }
    }

    private static func jsonValue(_ value: CellValue) -> Any {
        switch value {
        case .null: return NSNull()
        case .integer(let number): return number
        case .double(let number): return number
        case .text(let text): return text
        case .blob(let data): return data.base64EncodedString()
        }
    }
}

public struct CSVTable: Equatable {
    public var columns: [String]
    public var records: [[String: CellValue]]

    public init(columns: [String], records: [[String: CellValue]]) {
        self.columns = columns
        self.records = records
    }
}

public enum CSVImport {
    public static func parse(_ csv: String, hasHeader: Bool) throws -> CSVTable {
        let rows = parseRows(csv)
        guard !rows.isEmpty else {
            return CSVTable(columns: [], records: [])
        }
        let columns = hasHeader ? rows[0] : rows[0].enumerated().map { "column_\($0.offset + 1)" }
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        let records = dataRows.map { row -> [String: CellValue] in
            var record: [String: CellValue] = [:]
            for (index, column) in columns.enumerated() {
                let raw = index < row.count ? row[index] : ""
                record[column] = raw.isEmpty ? .null : .text(raw)
            }
            return record
        }
        return CSVTable(columns: columns, records: records)
    }

    private static func parseRows(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = csv.makeIterator()
        while let character = iterator.next() {
            if inQuotes {
                if character == "\"" {
                    if let next = peek(iterator), next == "\"" {
                        _ = iterator.next()
                        field.append("\"")
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == "," {
                row.append(field)
                field = ""
            } else if character == "\n" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character == "\r" {
                continue
            } else {
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private static func peek(_ iterator: String.Iterator) -> Character? {
        var copy = iterator
        return copy.next()
    }
}

public enum CSVExport {
    public static func serialize(columns: [String], rows: [[CellValue]]) -> String {
        var lines = [columns.map(escape).joined(separator: ",")]
        for row in rows {
            lines.append(zip(columns, row).map { _, value in escape(cell: value) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    private static func escape(cell: CellValue) -> String {
        switch cell {
        case .null: return ""
        case .integer(let number): return String(number)
        case .double(let number): return String(number)
        case .text(let text): return escape(text)
        case .blob: return ""
        }
    }
}
