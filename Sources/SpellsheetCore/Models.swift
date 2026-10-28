import Foundation

public let librarySchema = 1

public enum Ability: String, Codable, Hashable, CaseIterable, Sendable, Identifiable {
    case strength = "str"
    case dexterity = "dex"
    case constitution = "con"
    case intelligence = "int"
    case wisdom = "wis"
    case charisma = "cha"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .strength: "Strength"
        case .dexterity: "Dexterity"
        case .constitution: "Constitution"
        case .intelligence: "Intelligence"
        case .wisdom: "Wisdom"
        case .charisma: "Charisma"
        }
    }

    public var shortName: String {
        switch self {
        case .strength: "STR"
        case .dexterity: "DEX"
        case .constitution: "CON"
        case .intelligence: "INT"
        case .wisdom: "WIS"
        case .charisma: "CHA"
        }
    }

    public static func parse(_ raw: String) -> Ability? {
        let key = raw.lowercased()
        if let exact = Ability(rawValue: key) { return exact }
        switch key {
        case "strength": return .strength
        case "dexterity": return .dexterity
        case "constitution": return .constitution
        case "intelligence": return .intelligence
        case "wisdom": return .wisdom
        case "charisma": return .charisma
        default: return nil
        }
    }
}

public struct AbilityScores: Codable, Sendable, Equatable {
    public var strength: Int
    public var dexterity: Int
    public var constitution: Int
    public var intelligence: Int
    public var wisdom: Int
    public var charisma: Int

    public init(strength: Int, dexterity: Int, constitution: Int, intelligence: Int, wisdom: Int, charisma: Int) {
        self.strength = strength
        self.dexterity = dexterity
        self.constitution = constitution
        self.intelligence = intelligence
        self.wisdom = wisdom
        self.charisma = charisma
    }

    public static let tens = AbilityScores(
        strength: 10, dexterity: 10, constitution: 10,
        intelligence: 10, wisdom: 10, charisma: 10
    )

    public func score(_ ability: Ability) -> Int {
        switch ability {
        case .strength: strength
        case .dexterity: dexterity
        case .constitution: constitution
        case .intelligence: intelligence
        case .wisdom: wisdom
        case .charisma: charisma
        }
    }

    public mutating func set(_ ability: Ability, _ value: Int) {
        let clamped = min(30, max(1, value))
        switch ability {
        case .strength: strength = clamped
        case .dexterity: dexterity = clamped
        case .constitution: constitution = clamped
        case .intelligence: intelligence = clamped
        case .wisdom: wisdom = clamped
        case .charisma: charisma = clamped
        }
    }
}

public struct ClassRef: Codable, Hashable, Sendable {
    public var name: String
    public var source: String

    public init(name: String, source: String) {
        self.name = name
        self.source = source
    }
}

public struct SpellClassList: Codable, Sendable, Equatable {
    public var classes: [ClassRef]
    public var variants: [ClassRef]

    public init(classes: [ClassRef] = [], variants: [ClassRef] = []) {
        self.classes = classes
        self.variants = variants
    }
}

public enum GrantKind: String, Codable, Sendable {
    case alwaysPrepared
    case expandedList
}

public enum LevelGate: Codable, Hashable, Sendable {
    case always
    case classLevel(Int)
    case spellLevel(Int)

    public func isOpen(classLevel: Int, maxSpellLevel: Int) -> Bool {
        switch self {
        case .always: true
        case .classLevel(let required): classLevel >= required
        case .spellLevel(let required): maxSpellLevel >= required
        }
    }
}

public struct SpellGrant: Codable, Hashable, Sendable {
    public var focus: String?
    public var kind: GrantKind
    public var gate: LevelGate
    public var spellName: String?
    public var spellSource: String?
    public var filterLevel: Int?
    public var filterClassName: String?
    public var filterClassSource: String?

    public init(
        focus: String?,
        kind: GrantKind,
        gate: LevelGate,
        spellName: String? = nil,
        spellSource: String? = nil,
        filterLevel: Int? = nil,
        filterClassName: String? = nil,
        filterClassSource: String? = nil
    ) {
        self.focus = focus
        self.kind = kind
        self.gate = gate
        self.spellName = spellName
        self.spellSource = spellSource
        self.filterLevel = filterLevel
        self.filterClassName = filterClassName
        self.filterClassSource = filterClassSource
    }

    public var isFilter: Bool { filterClassName != nil || filterLevel != nil }
}

public struct ClassDefinition: Codable, Identifiable, Hashable, Sendable {
    public var name: String
    public var source: String
    public var edition: String
    public var spellcastingAbility: Ability?
    public var casterProgression: String?
    public var preparedFormula: String?
    public var preparedProgression: [Int]?
    public var spellsKnownProgression: [Int]?
    public var cantripProgression: [Int]?

    public var id: String { "\(name)|\(source)" }

    public init(
        name: String,
        source: String,
        edition: String,
        spellcastingAbility: Ability?,
        casterProgression: String?,
        preparedFormula: String?,
        preparedProgression: [Int]?,
        spellsKnownProgression: [Int]?,
        cantripProgression: [Int]?
    ) {
        self.name = name
        self.source = source
        self.edition = edition
        self.spellcastingAbility = spellcastingAbility
        self.casterProgression = casterProgression
        self.preparedFormula = preparedFormula
        self.preparedProgression = preparedProgression
        self.spellsKnownProgression = spellsKnownProgression
        self.cantripProgression = cantripProgression
    }

    public var editionLabel: String {
        switch edition {
        case "classic": "2014"
        case "one": "2024"
        default: edition
        }
    }
}

public struct SubclassDefinition: Codable, Identifiable, Hashable, Sendable {
    public var name: String
    public var shortName: String?
    public var source: String
    public var className: String
    public var classSource: String
    public var spellcastingAbility: Ability?
    public var casterProgression: String?
    public var preparedProgression: [Int]?
    public var spellsKnownProgression: [Int]?
    public var cantripProgression: [Int]?
    public var focuses: [String]
    public var grants: [SpellGrant]

    public var id: String { "\(className)|\(classSource)|\(name)|\(source)" }

    public init(
        name: String,
        shortName: String?,
        source: String,
        className: String,
        classSource: String,
        spellcastingAbility: Ability?,
        casterProgression: String?,
        preparedProgression: [Int]?,
        spellsKnownProgression: [Int]?,
        cantripProgression: [Int]?,
        focuses: [String],
        grants: [SpellGrant]
    ) {
        self.name = name
        self.shortName = shortName
        self.source = source
        self.className = className
        self.classSource = classSource
        self.spellcastingAbility = spellcastingAbility
        self.casterProgression = casterProgression
        self.preparedProgression = preparedProgression
        self.spellsKnownProgression = spellsKnownProgression
        self.cantripProgression = cantripProgression
        self.focuses = focuses
        self.grants = grants
    }
}

public struct SubclassCopy: Sendable {
    public var name: String
    public var shortName: String?
    public var source: String
    public var className: String
    public var classSource: String
    public var copyName: String
    public var copySource: String
    public var copyClassName: String
    public var copyClassSource: String
}

public struct SpellBlock: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case paragraph, heading, bullet, table }

    public var id: Int
    public var kind: Kind
    public var text: String
    public var columns: [String]
    public var rows: [[String]]

    public init(id: Int, kind: Kind, text: String, columns: [String] = [], rows: [[String]] = []) {
        self.id = id
        self.kind = kind
        self.text = text
        self.columns = columns
        self.rows = rows
    }
}

public struct SpellScaling: Codable, Hashable, Sendable {
    public var level: Int
    public var dice: String

    public init(level: Int, dice: String) {
        self.level = level
        self.dice = dice
    }
}

public struct Spell: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var source: String
    public var page: Int?
    public var level: Int
    public var school: String
    public var castingTime: String
    public var range: String
    public var components: String
    public var material: String?
    public var duration: String
    public var concentration: Bool
    public var ritual: Bool
    public var savingThrows: [String]
    public var attackKinds: [String]
    public var damage: [String]
    public var description: [SpellBlock]
    public var higherLevel: [SpellBlock]
    public var scaling: [SpellScaling]

    public var id: String { "\(name)|\(source)" }
    public var listKey: String { Spell.listKey(name: name, source: source) }

    public static func listKey(name: String, source: String) -> String {
        "\(name.lowercased())|\(source.uppercased())"
    }

    public init(
        name: String,
        source: String,
        page: Int?,
        level: Int,
        school: String,
        castingTime: String,
        range: String,
        components: String,
        material: String?,
        duration: String,
        concentration: Bool,
        ritual: Bool,
        savingThrows: [String],
        attackKinds: [String],
        damage: [String],
        description: [SpellBlock],
        higherLevel: [SpellBlock],
        scaling: [SpellScaling]
    ) {
        self.name = name
        self.source = source
        self.page = page
        self.level = level
        self.school = school
        self.castingTime = castingTime
        self.range = range
        self.components = components
        self.material = material
        self.duration = duration
        self.concentration = concentration
        self.ritual = ritual
        self.savingThrows = savingThrows
        self.attackKinds = attackKinds
        self.damage = damage
        self.description = description
        self.higherLevel = higherLevel
        self.scaling = scaling
    }

    public var schoolName: String { Spell.schoolName(school) }
    public var levelName: String { Spell.levelName(level) }

    public static func schoolName(_ code: String) -> String {
        switch code.uppercased() {
        case "A": "Abjuration"
        case "C": "Conjuration"
        case "D": "Divination"
        case "E": "Enchantment"
        case "I": "Illusion"
        case "N": "Necromancy"
        case "P": "Psionic"
        case "T": "Transmutation"
        case "V": "Evocation"
        default: code
        }
    }

    public static func levelName(_ level: Int) -> String {
        if level <= 0 { return "Cantrip" }
        return "\(ordinal(level)) level"
    }

    public var fiveEToolsURL: URL? {
        if source.caseInsensitiveCompare(HomebrewSpell.source) == .orderedSame { return nil }
        return Spell.fiveEToolsURL(name: name, source: source)
    }

    public static func fiveEToolsURL(name: String, source: String) -> URL? {
        func encode(_ value: String) -> String {
            var allowed = CharacterSet.urlFragmentAllowed
            allowed.remove(charactersIn: " #'/?&")
            return value.lowercased().addingPercentEncoding(withAllowedCharacters: allowed) ?? value.lowercased()
        }
        return URL(string: "https://5e.tools/spells.html#\(encode(name))_\(encode(source))")
    }

    public func dice(atCharacterLevel level: Int) -> String? {
        let sorted = scaling.sorted { $0.level < $1.level }
        return sorted.last { $0.level <= max(level, 1) }?.dice ?? sorted.first?.dice
    }
}

public func ordinal(_ number: Int) -> String {
    let suffix: String
    switch number % 100 {
    case 11, 12, 13: suffix = "th"
    default:
        switch number % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(number)\(suffix)"
}

public struct Library: Codable, Sendable {
    public var schema: Int
    public var fetchedAt: Date
    public var sourceNames: [String: String]
    public var classes: [ClassDefinition]
    public var subclasses: [SubclassDefinition]
    public var spells: [Spell]
    public var lists: [String: SpellClassList]

    public init(
        schema: Int = librarySchema,
        fetchedAt: Date,
        sourceNames: [String: String],
        classes: [ClassDefinition],
        subclasses: [SubclassDefinition],
        spells: [Spell],
        lists: [String: SpellClassList]
    ) {
        self.schema = schema
        self.fetchedAt = fetchedAt
        self.sourceNames = sourceNames
        self.classes = classes
        self.subclasses = subclasses
        self.spells = spells
        self.lists = lists
    }

    public func sourceName(_ code: String) -> String {
        sourceNames[code] ?? sourceNames[code.uppercased()] ?? code
    }
}

public struct LibraryIndex: Sendable {
    public let library: Library
    public let spellsByID: [String: Spell]
    public let spellsByName: [String: [Spell]]

    public init(library: Library) {
        self.library = library
        var byID: [String: Spell] = [:]
        var byName: [String: [Spell]] = [:]
        byID.reserveCapacity(library.spells.count)
        for spell in library.spells {
            byID[spell.id] = spell
            byName[spell.name.lowercased(), default: []].append(spell)
        }
        self.spellsByID = byID
        self.spellsByName = byName
    }

    public func spell(id: String) -> Spell? { spellsByID[id] }

    public func spell(name: String, source: String) -> Spell? {
        spellsByID["\(name)|\(source)"] ?? spellsByName[name.lowercased()]?.first { $0.source.caseInsensitiveCompare(source) == .orderedSame }
    }

    /// Picks the printing that matches an explicit source, then the caster's edition.
    public func resolve(name: String, source: String?, edition: String, classSource: String) -> Spell? {
        let matches = spellsByName[name.lowercased()] ?? []
        if matches.isEmpty { return nil }
        if let source {
            if let exact = matches.first(where: { $0.source.caseInsensitiveCompare(source) == .orderedSame }) {
                return exact
            }
        }
        if let sameBook = matches.first(where: { $0.source.caseInsensitiveCompare(classSource) == .orderedSame }) {
            return sameBook
        }
        let preferred = edition == "one" ? "XPHB" : "PHB"
        if let preferredSpell = matches.first(where: { $0.source.caseInsensitiveCompare(preferred) == .orderedSame }) {
            return preferredSpell
        }
        if edition == "one" {
            return matches.first { $0.source.uppercased().hasPrefix("X") } ?? matches[0]
        }
        return matches.first { !$0.source.uppercased().hasPrefix("X") } ?? matches[0]
    }
}

public struct ClassPick: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var className: String
    public var classSource: String
    public var level: Int
    public var subclassName: String?
    public var subclassSource: String?
    public var focus: String?
    public var abilityOverride: Ability?

    public init(
        id: UUID = UUID(),
        className: String,
        classSource: String,
        level: Int,
        subclassName: String? = nil,
        subclassSource: String? = nil,
        focus: String? = nil,
        abilityOverride: Ability? = nil
    ) {
        self.id = id
        self.className = className
        self.classSource = classSource
        self.level = min(20, max(1, level))
        self.subclassName = subclassName
        self.subclassSource = subclassSource
        self.focus = focus
        self.abilityOverride = abilityOverride
    }
}

public struct CharacterSheet: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var scores: AbilityScores
    public var classes: [ClassPick]
    public var preparedIDs: [String]
    public var expendedSlots: [Int]
    public var expendedPact: Int
    public var includeVariants: Bool

    public init(
        id: UUID,
        name: String,
        scores: AbilityScores,
        classes: [ClassPick],
        preparedIDs: [String],
        expendedSlots: [Int],
        expendedPact: Int,
        includeVariants: Bool
    ) {
        self.id = id
        self.name = name
        self.scores = scores
        self.classes = classes
        self.preparedIDs = preparedIDs
        self.expendedSlots = expendedSlots.count == 10 ? expendedSlots : Array(repeating: 0, count: 10)
        self.expendedPact = expendedPact
        self.includeVariants = includeVariants
    }

    public static func makeNew() -> CharacterSheet {
        CharacterSheet(
            id: UUID(),
            name: "New Caster",
            scores: .tens,
            classes: [],
            preparedIDs: [],
            expendedSlots: Array(repeating: 0, count: 10),
            expendedPact: 0,
            includeVariants: false
        )
    }

    public var totalLevel: Int { classes.reduce(0) { $0 + $1.level } }
}

public enum ListMode: String, CaseIterable, Hashable, Sendable, Identifiable {
    case sheet = "On sheet"
    case catalog = "Class list"

    public var id: String { rawValue }
}
