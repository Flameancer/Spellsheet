import Foundation

public enum EntryText {
    private static let tagPattern = try! NSRegularExpression(
        pattern: #"\{@([A-Za-z]+)(?:\s+([^{}]*))?\}"#
    )

    public static func plain(_ input: String) -> String {
        var text = input
        for _ in 0..<16 {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = tagPattern.firstMatch(in: text, range: range),
                  let whole = Range(match.range, in: text),
                  let tagRange = Range(match.range(at: 1), in: text)
            else { break }
            let tag = String(text[tagRange]).lowercased()
            let payload: String
            if match.range(at: 2).location != NSNotFound, let payloadRange = Range(match.range(at: 2), in: text) {
                payload = String(text[payloadRange])
            } else {
                payload = ""
            }
            text.replaceSubrange(whole, with: replacement(tag: tag, payload: payload))
        }
        return text
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " \n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func blocks(from entries: [Any]) -> [SpellBlock] {
        var output: [SpellBlock] = []
        var nextID = 0
        append(entries, to: &output, nextID: &nextID)
        return output
    }

    /// Pulls "At Higher Levels" style sections out of the main text when the spell has no separate field.
    public static func splitHigherLevel(_ blocks: [SpellBlock]) -> (body: [SpellBlock], higher: [SpellBlock]) {
        let titles: Set<String> = [
            "at higher levels",
            "cantrip upgrade",
            "using a higher-level spell slot",
            "using a higher level spell slot",
        ]
        var body: [SpellBlock] = []
        var higher: [SpellBlock] = []
        var diverting = false
        for block in blocks {
            if block.kind == .heading && titles.contains(block.text.lowercased()) {
                diverting = true
                higher.append(block)
                continue
            }
            if diverting && block.kind == .heading {
                diverting = false
            }
            if diverting {
                higher.append(block)
            } else {
                body.append(block)
            }
        }
        return (body, higher)
    }

    private static func replacement(tag: String, payload: String) -> String {
        let segments = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        func first() -> String { segments.first?.trimmingCharacters(in: .whitespaces) ?? "" }
        func lastDisplay() -> String {
            if segments.count >= 3 {
                let last = segments[segments.count - 1].trimmingCharacters(in: .whitespaces)
                if !last.isEmpty && !last.contains("=") { return last }
            }
            return first()
        }
        switch tag {
        case "h":
            return "\n"
        case "hit":
            let number = first().trimmingCharacters(in: CharacterSet(charactersIn: "+"))
            return number.hasPrefix("-") ? number : "+\(number)"
        case "dc":
            return "DC \(first())"
        case "scaledamage", "scaledice":
            let dice = segments.last?.trimmingCharacters(in: .whitespaces) ?? first()
            return dice.isEmpty ? first() : dice
        case "dice", "damage", "d20", "hitYourSpellAttack":
            return first()
        case "filter", "book", "adventure":
            return first()
        case "note", "i", "b", "bold", "italic", "underline", "s", "strike", "u", "highlight", "help":
            return plain(payload)
        default:
            return lastDisplay()
        }
    }

    private static func append(_ entries: [Any], to output: inout [SpellBlock], nextID: inout Int) {
        for entry in entries {
            appendOne(entry, to: &output, nextID: &nextID)
        }
    }

    private static func appendOne(_ entry: Any, to output: inout [SpellBlock], nextID: inout Int) {
        if let text = entry as? String {
            let rendered = plain(text)
            guard !rendered.isEmpty else { return }
            output.append(SpellBlock(id: nextID, kind: .paragraph, text: rendered))
            nextID += 1
            return
        }
        guard let object = entry as? [String: Any] else { return }
        let type = (object["type"] as? String) ?? "entries"
        switch type {
        case "list":
            for item in object["items"] as? [Any] ?? [] {
                appendListItem(item, to: &output, nextID: &nextID)
            }
        case "table":
            let caption = (object["caption"] as? String).map(plain) ?? ""
            let columns = (object["colLabels"] as? [Any] ?? []).map { plain(stringify($0)) }
            let rows = (object["rows"] as? [Any] ?? []).compactMap { row -> [String]? in
                guard let cells = row as? [Any] else { return nil }
                return cells.map { plain(stringify($0)) }
            }
            output.append(SpellBlock(id: nextID, kind: .table, text: caption, columns: columns, rows: rows))
            nextID += 1
        case "cell":
            let text = plain(stringify(object))
            guard !text.isEmpty else { return }
            output.append(SpellBlock(id: nextID, kind: .paragraph, text: text))
            nextID += 1
        default:
            if let name = object["name"] as? String {
                let heading = plain(name)
                if !heading.isEmpty {
                    output.append(SpellBlock(id: nextID, kind: .heading, text: heading))
                    nextID += 1
                }
            }
            if let children = object["entries"] as? [Any] {
                append(children, to: &output, nextID: &nextID)
            } else if let child = object["entry"] {
                appendOne(child, to: &output, nextID: &nextID)
            } else if let items = object["items"] as? [Any] {
                for item in items { appendListItem(item, to: &output, nextID: &nextID) }
            }
        }
    }

    private static func appendListItem(_ item: Any, to output: inout [SpellBlock], nextID: inout Int) {
        if let text = item as? String {
            let rendered = plain(text)
            guard !rendered.isEmpty else { return }
            output.append(SpellBlock(id: nextID, kind: .bullet, text: rendered))
            nextID += 1
            return
        }
        guard let object = item as? [String: Any] else { return }
        let name = (object["name"] as? String).map(plain) ?? ""
        var detail = ""
        if let entry = object["entry"] as? String {
            detail = plain(entry)
        } else if let entry = object["entry"] as? [String: Any] {
            detail = plain(stringify(entry))
        }
        if let entries = object["entries"] as? [Any] {
            let flat = entries.map { plain(stringify($0)) }.filter { !$0.isEmpty }.joined(separator: " ")
            if !flat.isEmpty { detail = detail.isEmpty ? flat : "\(detail) \(flat)" }
        }
        let line = [name, detail].filter { !$0.isEmpty }.joined(separator: " — ")
        guard !line.isEmpty else { return }
        output.append(SpellBlock(id: nextID, kind: .bullet, text: line))
        nextID += 1
    }

    private static func stringify(_ value: Any) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        guard let object = value as? [String: Any] else { return "" }
        if let roll = object["roll"] as? [String: Any] {
            if let exact = roll["exact"] { return "\(stringify(exact))" }
            if let min = roll["min"], let max = roll["max"] { return "\(stringify(min))–\(stringify(max))" }
        }
        if let entry = object["entry"] as? String { return entry }
        if let entries = object["entries"] as? [Any] {
            return entries.map(stringify).filter { !$0.isEmpty }.joined(separator: " ")
        }
        if let text = object["text"] as? String { return text }
        return ""
    }
}
