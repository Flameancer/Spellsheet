import Foundation

public enum CatalogParser {
    public static func bookNames(from data: Data) throws -> [String: String] {
        let root = try jsonObject(data)
        var names: [String: String] = [:]
        for book in array(root["book"]) {
            guard let object = book as? [String: Any],
                  let id = string(object["id"]) ?? string(object["source"]),
                  let name = string(object["name"])
            else { continue }
            names[id] = name
        }
        return names
    }

    public static func spellIndex(from data: Data) throws -> [String: String] {
        let root = try jsonObject(data)
        var index: [String: String] = [:]
        for (key, value) in root {
            if let file = value as? String, file.hasPrefix("spells-") {
                index[key] = file
            }
        }
        return index
    }

    public static func classIndex(from data: Data) throws -> [String: String] {
        let root = try jsonObject(data)
        var index: [String: String] = [:]
        for (key, value) in root {
            if let file = value as? String, file.hasPrefix("class-") {
                index[key] = file
            }
        }
        return index
    }

    public static func classLists(from data: Data) throws -> [String: SpellClassList] {
        let root = try jsonObject(data)
        var lists: [String: SpellClassList] = [:]
        for (source, spells) in root {
            guard let spellMap = spells as? [String: Any] else { continue }
            for (name, value) in spellMap {
                guard let info = value as? [String: Any] else { continue }
                let key = Spell.listKey(name: name, source: source)
                lists[key] = SpellClassList(
                    classes: refs(info["class"]),
                    variants: refs(info["classVariant"])
                )
            }
        }
        return lists
    }

    public struct ClassFile {
        public var classes: [ClassDefinition]
        public var subclasses: [SubclassDefinition]
        public var copies: [SubclassCopy]
    }

    public static func classFile(from data: Data) throws -> ClassFile {
        let root = try jsonObject(data)
        let classes = array(root["class"]).compactMap { item -> ClassDefinition? in
            guard let object = item as? [String: Any], object["_copy"] == nil else { return nil }
            guard let name = string(object["name"]), let source = string(object["source"]) else { return nil }
            return ClassDefinition(
                name: name,
                source: source,
                edition: string(object["edition"]) ?? "classic",
                spellcastingAbility: string(object["spellcastingAbility"]).flatMap(Ability.parse),
                casterProgression: string(object["casterProgression"]),
                preparedFormula: string(object["preparedSpells"]),
                preparedProgression: intList(object["preparedSpellsProgression"]),
                spellsKnownProgression: intList(object["spellsKnownProgression"]),
                cantripProgression: intList(object["cantripProgression"])
            )
        }
        var subclasses: [SubclassDefinition] = []
        var copies: [SubclassCopy] = []
        for item in array(root["subclass"]) {
            guard let object = item as? [String: Any],
                  let name = string(object["name"]),
                  let source = string(object["source"]),
                  let className = string(object["className"]),
                  let classSource = string(object["classSource"])
            else { continue }
            if let copy = object["_copy"] as? [String: Any],
               let copyName = string(copy["name"]),
               let copySource = string(copy["source"]),
               let copyClassName = string(copy["className"]),
               let copyClassSource = string(copy["classSource"]) {
                copies.append(SubclassCopy(
                    name: name,
                    shortName: string(object["shortName"]),
                    source: source,
                    className: className,
                    classSource: classSource,
                    copyName: copyName,
                    copySource: copySource,
                    copyClassName: copyClassName,
                    copyClassSource: copyClassSource
                ))
                continue
            }
            subclasses.append(parseSubclass(object))
        }
        return ClassFile(classes: classes, subclasses: subclasses, copies: copies)
    }

    public static func resolveCopies(_ subclasses: [SubclassDefinition], copies: [SubclassCopy]) -> [SubclassDefinition] {
        var resolved = subclasses
        var pending = copies
        var guardrail = pending.count + 2
        while !pending.isEmpty && guardrail > 0 {
            guardrail -= 1
            var stillPending: [SubclassCopy] = []
            for copy in pending {
                guard let source = resolved.first(where: {
                    $0.name == copy.copyName && $0.source == copy.copySource
                        && $0.className == copy.copyClassName && $0.classSource == copy.copyClassSource
                }) else {
                    stillPending.append(copy)
                    continue
                }
                var clone = source
                clone.name = copy.name
                clone.shortName = copy.shortName ?? source.shortName
                clone.source = copy.source
                clone.className = copy.className
                clone.classSource = copy.classSource
                if !resolved.contains(where: { $0.id == clone.id }) {
                    resolved.append(clone)
                }
            }
            if stillPending.count == pending.count { break }
            pending = stillPending
        }
        return resolved
    }

    public static func spells(from data: Data) throws -> [Spell] {
        let root = try jsonObject(data)
        return array(root["spell"]).compactMap { item in
            guard let object = item as? [String: Any] else { return nil }
            return parseSpell(object)
        }
    }

    public static func parseSpell(_ object: [String: Any]) -> Spell? {
        guard let name = string(object["name"]), let source = string(object["source"]) else { return nil }
        let mainEntries = array(object["entries"])
        let higherEntries = array(object["entriesHigherLevel"])
        var body = EntryText.blocks(from: mainEntries)
        let split = EntryText.splitHigherLevel(body)
        body = split.body
        var higher = EntryText.blocks(from: higherEntries)
        if higher.isEmpty { higher = split.higher }
        let duration = formatDuration(object["duration"])
        let components = formatComponents(object["components"])
        return Spell(
            name: name,
            source: source,
            page: int(object["page"]),
            level: int(object["level"]) ?? 0,
            school: string(object["school"]) ?? "",
            castingTime: formatTime(object["time"]),
            range: formatRange(object["range"]),
            components: components.summary,
            material: components.material,
            duration: duration.text,
            concentration: duration.concentration,
            ritual: ((object["meta"] as? [String: Any])?["ritual"] as? Bool) ?? false,
            savingThrows: stringList(object["savingThrow"]).map(capitalizedWord),
            attackKinds: stringList(object["spellAttack"]),
            damage: stringList(object["damageInflict"]).map(capitalizedWord),
            description: body,
            higherLevel: higher,
            scaling: formatScaling(object["scalingLevelDice"])
        )
    }

    private static func parseSubclass(_ object: [String: Any]) -> SubclassDefinition {
        let name = string(object["name"]) ?? "Subclass"
        let source = string(object["source"]) ?? ""
        let grants = grants(from: object["additionalSpells"])
        let focuses = Array(Set(grants.compactMap(\.focus))).sorted()
        return SubclassDefinition(
            name: name,
            shortName: string(object["shortName"]),
            source: source,
            className: string(object["className"]) ?? "",
            classSource: string(object["classSource"]) ?? "",
            spellcastingAbility: string(object["spellcastingAbility"]).flatMap(Ability.parse),
            casterProgression: string(object["casterProgression"]),
            preparedProgression: intList(object["preparedSpellsProgression"]),
            spellsKnownProgression: intList(object["spellsKnownProgression"]),
            cantripProgression: intList(object["cantripProgression"]),
            focuses: focuses,
            grants: grants
        )
    }

    static func grants(from raw: Any?) -> [SpellGrant] {
        var output: [SpellGrant] = []
        for block in array(raw) {
            guard let object = block as? [String: Any] else { continue }
            let focus = string(object["name"])
            for (key, value) in object {
                let kind: GrantKind
                switch key {
                case "prepared", "known", "innate": kind = .alwaysPrepared
                case "expanded": kind = .expandedList
                default: continue
                }
                walkGrant(value, focus: focus, kind: kind, gate: .always, into: &output)
            }
        }
        return output
    }

    private static func walkGrant(
        _ value: Any,
        focus: String?,
        kind: GrantKind,
        gate: LevelGate,
        into output: inout [SpellGrant]
    ) {
        if let text = value as? String {
            let ref = spellReference(text)
            output.append(SpellGrant(
                focus: focus, kind: kind, gate: gate,
                spellName: ref.name, spellSource: ref.source
            ))
            return
        }
        if let list = value as? [Any] {
            for item in list { walkGrant(item, focus: focus, kind: kind, gate: gate, into: &output) }
            return
        }
        guard let object = value as? [String: Any] else { return }
        if let filter = string(object["all"]) {
            output.append(filterGrant(filter, focus: focus, kind: kind, gate: gate))
            return
        }
        if object["choose"] != nil { return }
        for (key, child) in object {
            if key == "name" || key == "count" { continue }
            let childGate = gateForKey(key) ?? gate
            walkGrant(child, focus: focus, kind: kind, gate: childGate, into: &output)
        }
    }

    private static func gateForKey(_ key: String) -> LevelGate? {
        if key == "_" || key == "daily" || key == "rest" || key == "will" || key == "resource" { return nil }
        if let level = Int(key) { return .classLevel(level) }
        if key.hasPrefix("s"), let level = Int(key.dropFirst()), level > 0 { return .spellLevel(level) }
        if Ability.parse(key) != nil { return nil }
        return nil
    }

    private static func filterGrant(_ filter: String, focus: String?, kind: GrantKind, gate: LevelGate) -> SpellGrant {
        var level: Int?
        var className: String?
        var classSource: String?
        for part in filter.split(separator: "|").map(String.init) {
            let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
            if pieces.count == 2 {
                switch pieces[0] {
                case "level": level = Int(pieces[1])
                case "class": className = pieces[1]
                default: break
                }
            } else if className != nil && classSource == nil {
                classSource = part
            }
        }
        return SpellGrant(
            focus: focus,
            kind: kind,
            gate: gate,
            filterLevel: level,
            filterClassName: className,
            filterClassSource: classSource
        )
    }

    static func spellReference(_ raw: String) -> (name: String, source: String?) {
        var text = raw
        if let hash = text.firstIndex(of: "#") { text = String(text[..<hash]) }
        let parts = text.split(separator: "|", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return (parts[0], parts[1].uppercased())
        }
        return (text, nil)
    }

    static func refs(_ raw: Any?) -> [ClassRef] {
        array(raw).compactMap { item in
            guard let object = item as? [String: Any],
                  let name = string(object["name"]),
                  let source = string(object["source"])
            else { return nil }
            return ClassRef(name: name, source: source)
        }
    }

    private static func formatTime(_ raw: Any?) -> String {
        let times = array(raw).compactMap { item -> String? in
            guard let object = item as? [String: Any] else { return nil }
            let number = int(object["number"]) ?? 1
            let unit = string(object["unit"]) ?? "action"
            let condition = string(object["condition"]).map(EntryText.plain)
            var text = "\(number) \(timeUnit(unit, number: number))"
            if let condition, !condition.isEmpty { text += ", \(condition)" }
            return text
        }
        return times.isEmpty ? "1 action" : times.joined(separator: " or ")
    }

    private static func timeUnit(_ unit: String, number: Int) -> String {
        switch unit {
        case "bonus": return number == 1 ? "bonus action" : "bonus actions"
        case "reaction": return "reaction"
        case "action": return number == 1 ? "action" : "actions"
        case "minute": return number == 1 ? "minute" : "minutes"
        case "hour": return number == 1 ? "hour" : "hours"
        case "round": return number == 1 ? "round" : "rounds"
        default: return unit
        }
    }

    private static func formatRange(_ raw: Any?) -> String {
        guard let object = raw as? [String: Any] else { return "Special" }
        let type = string(object["type"]) ?? "special"
        if type == "special" { return "Special" }
        let distance = object["distance"] as? [String: Any]
        let distanceType = string(distance?["type"]) ?? ""
        let amount = int(distance?["amount"])
        let shape = distancePhrase(type: distanceType, amount: amount)
        switch type {
        case "point":
            return shape
        case "radius", "sphere", "cone", "line", "cube", "hemisphere":
            if distanceType == "self" || shape == "Self" {
                if let amount { return "Self (\(amount)-foot \(type))" }
                return "Self"
            }
            if shape == "Touch" || shape == "Sight" { return shape }
            return "\(shape) \(type)"
        default:
            return shape
        }
    }

    private static func distancePhrase(type: String, amount: Int?) -> String {
        switch type {
        case "feet":
            guard let amount else { return "Special" }
            return amount == 1 ? "1 foot" : "\(amount) feet"
        case "miles":
            guard let amount else { return "Special" }
            return amount == 1 ? "1 mile" : "\(amount) miles"
        case "touch": return "Touch"
        case "self": return "Self"
        case "sight": return "Sight"
        case "unlimited": return "Unlimited"
        case "plane": return "Same plane"
        default: return type.isEmpty ? "Special" : type.capitalized
        }
    }

    private static func formatDuration(_ raw: Any?) -> (text: String, concentration: Bool) {
        var concentration = false
        let parts = array(raw).compactMap { item -> String? in
            guard let object = item as? [String: Any] else { return nil }
            if object["concentration"] as? Bool == true { concentration = true }
            switch string(object["type"]) ?? "" {
            case "instant": return "Instantaneous"
            case "permanent":
                let ends = stringList(object["ends"])
                if ends.isEmpty { return "Permanent" }
                return "Until " + ends.map(endPhrase).joined(separator: " or ")
            case "special": return "Special"
            case "timed":
                let duration = object["duration"] as? [String: Any]
                let amount = int(duration?["amount"]) ?? 1
                let unit = string(duration?["type"]) ?? "round"
                let noun = amount == 1 ? unit : "\(unit)s"
                let prefix = concentration ? "Concentration, up to " : ""
                return prefix + "\(amount) \(noun)"
            default: return "Special"
            }
        }
        return (parts.isEmpty ? "Special" : parts.joined(separator: " or "), concentration)
    }

    private static func endPhrase(_ end: String) -> String {
        switch end {
        case "dispel": return "dispelled"
        case "trigger": return "triggered"
        case "discharge": return "discharged"
        default: return end
        }
    }

    private static func formatComponents(_ raw: Any?) -> (summary: String, material: String?) {
        guard let object = raw as? [String: Any] else { return ("None", nil) }
        var letters: [String] = []
        if object["v"] as? Bool == true { letters.append("V") }
        if object["s"] as? Bool == true { letters.append("S") }
        var material: String?
        if let materialRaw = object["m"] {
            letters.append("M")
            material = formatMaterial(materialRaw)
        }
        let summary = letters.isEmpty ? "None" : letters.joined(separator: ", ")
        return (summary, material)
    }

    private static func formatMaterial(_ raw: Any) -> String {
        if let text = raw as? String { return EntryText.plain(text) }
        guard let object = raw as? [String: Any] else { return "" }
        var text = string(object["text"]).map(EntryText.plain) ?? ""
        var notes: [String] = []
        if let cost = int(object["cost"]), cost > 0 { notes.append(formatCoin(cost)) }
        if object["consume"] as? Bool == true { notes.append("consumed") }
        if !notes.isEmpty {
            text += text.isEmpty ? notes.joined(separator: ", ") : " (\(notes.joined(separator: ", ")))"
        }
        return text
    }

    /// 5e.tools stores component costs in copper pieces.
    static func formatCoin(_ copper: Int) -> String {
        if copper % 100 == 0 { return "\(copper / 100) gp" }
        if copper % 10 == 0 { return "\(copper / 10) sp" }
        return "\(copper) cp"
    }

    private static func formatScaling(_ raw: Any?) -> [SpellScaling] {
        guard let object = raw as? [String: Any], let scaling = object["scaling"] as? [String: Any] else { return [] }
        return scaling.compactMap { key, value in
            guard let level = Int(key), let dice = value as? String else { return nil }
            return SpellScaling(level: level, dice: dice)
        }.sorted { $0.level < $1.level }
    }

    static func jsonObject(_ data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw CatalogError.malformed("Expected a JSON object")
        }
        return dictionary
    }

    static func array(_ raw: Any?) -> [Any] {
        raw as? [Any] ?? []
    }

    static func string(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        return nil
    }

    private static func int(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() { return value.intValue }
        return nil
    }

    private static func intList(_ raw: Any?) -> [Int]? {
        guard let list = raw as? [Any] else { return nil }
        let values = list.compactMap { int($0) }
        return values.isEmpty ? nil : values
    }

    private static func stringList(_ raw: Any?) -> [String] {
        (raw as? [Any])?.compactMap { $0 as? String } ?? []
    }

    private static func capitalizedWord(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }
}

public enum CatalogError: Error, CustomStringConvertible, LocalizedError, Sendable {
    case malformed(String)
    case http(Int, String)
    case address(String)

    public var description: String {
        switch self {
        case .malformed(let message): message
        case .http(let code, let path): "The 5e.tools data request failed (\(code)) for \(path)."
        case .address(let path): "Could not build a URL for \(path)."
        }
    }

    public var errorDescription: String? { description }
}
