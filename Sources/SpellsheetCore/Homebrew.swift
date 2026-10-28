import Foundation

public struct HomebrewSpell: Codable, Identifiable, Equatable, Sendable {
    public static let source = "HB"

    public var id: UUID
    public var name: String
    public var level: Int
    public var school: String
    public var castingTime: String
    public var range: String
    public var duration: String
    public var components: String
    public var concentration: Bool
    public var ritual: Bool
    public var summary: String
    public var higherLevel: String
    public var classes: [ClassRef]

    public init(
        id: UUID = UUID(),
        name: String,
        level: Int = 1,
        school: String = "V",
        castingTime: String = "1 action",
        range: String = "60 feet",
        duration: String = "Instantaneous",
        components: String = "V, S",
        concentration: Bool = false,
        ritual: Bool = false,
        summary: String = "",
        higherLevel: String = "",
        classes: [ClassRef] = []
    ) {
        self.id = id
        self.name = name
        self.level = min(9, max(0, level))
        self.school = school
        self.castingTime = castingTime
        self.range = range
        self.duration = duration
        self.components = components
        self.concentration = concentration
        self.ritual = ritual
        self.summary = summary
        self.higherLevel = higherLevel
        self.classes = classes
    }

    public static func makeNew() -> HomebrewSpell {
        HomebrewSpell(name: "New Spell")
    }

    public var spellID: String { "\(name)|\(Self.source)" }

    public func asSpell() -> Spell {
        let lines = summary.split(separator: "\n", omittingEmptySubsequences: false)
        let paragraphs = lines.enumerated().map { index, line in
            SpellBlock(id: index, kind: .paragraph, text: String(line))
        }
        let body = paragraphs.isEmpty
            ? [SpellBlock(id: 0, kind: .paragraph, text: "")]
            : paragraphs
        var higher: [SpellBlock] = []
        let higherText = higherLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !higherText.isEmpty {
            higher = [
                SpellBlock(id: 0, kind: .heading, text: "At Higher Levels"),
                SpellBlock(id: 1, kind: .paragraph, text: higherText),
            ]
        }
        return Spell(
            name: name,
            source: Self.source,
            page: nil,
            level: level,
            school: school,
            castingTime: castingTime,
            range: range,
            components: components,
            material: nil,
            duration: duration,
            concentration: concentration,
            ritual: ritual,
            savingThrows: [],
            attackKinds: [],
            damage: [],
            description: body,
            higherLevel: higher,
            scaling: []
        )
    }
}

public extension Library {
    /// Official data stays in the cache. Homebrew is layered on top for the spell lists.
    func addingHomebrew(_ spells: [HomebrewSpell]) -> Library {
        let usable = spells.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !usable.isEmpty else { return self }
        var copy = self
        copy.sourceNames[HomebrewSpell.source] = "Homebrew"
        for brew in usable {
            let spell = brew.asSpell()
            copy.spells.removeAll { $0.id == spell.id }
            copy.spells.append(spell)
            copy.lists[spell.listKey] = SpellClassList(classes: brew.classes)
        }
        copy.spells.sort { lhs, rhs in
            if lhs.level != rhs.level { return lhs.level < rhs.level }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return copy
    }

    /// Layer repository brews on top of the official cache. Brew-owned sources can add spells.
    /// A brew does not replace the text of a spell the official library already has.
    func addingBrews(_ documents: [BrewDocument]) -> Library {
        guard !documents.isEmpty else { return self }
        var copy = self
        for document in documents {
            for (code, name) in document.sourceNames {
                copy.sourceNames[code] = name
            }
            for var spell in document.spells {
                if let fill = document.copies.first(where: { $0.spellID == spell.id }),
                   spell.description.allSatisfy({ $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                   let original = copy.spells.first(where: {
                       $0.name.caseInsensitiveCompare(fill.copyName) == .orderedSame
                           && $0.source.caseInsensitiveCompare(fill.copySource) == .orderedSame
                   }) {
                    spell.description = original.description
                    if spell.higherLevel.isEmpty { spell.higherLevel = original.higherLevel }
                    if spell.scaling.isEmpty { spell.scaling = original.scaling }
                    if spell.school.isEmpty { spell.school = original.school }
                }
                let owned = document.sourceNames[spell.source] != nil
                if let index = copy.spells.firstIndex(where: { $0.id == spell.id }) {
                    if owned && !self.spells.contains(where: { $0.id == spell.id }) {
                        copy.spells[index] = spell
                    }
                } else if owned {
                    copy.spells.append(spell)
                }
            }
            for (key, extra) in document.lists {
                copy.lists[key] = unionClasses(copy.lists[key], extra)
            }
            for (key, names) in document.bareClasses {
                var extra = SpellClassList()
                for name in names {
                    let matches = copy.classes.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                    if matches.isEmpty {
                        extra.classes.append(ClassRef(name: name, source: "PHB"))
                    } else {
                        extra.classes.append(contentsOf: matches.map { ClassRef(name: $0.name, source: $0.source) })
                    }
                }
                copy.lists[key] = unionClasses(copy.lists[key], extra)
            }
        }
        copy.spells.sort { lhs, rhs in
            if lhs.level != rhs.level { return lhs.level < rhs.level }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return copy
    }

    private func unionClasses(_ base: SpellClassList?, _ extra: SpellClassList) -> SpellClassList {
        var list = base ?? SpellClassList()
        for ref in extra.classes where !list.classes.contains(where: { $0.name == ref.name && $0.source == ref.source }) {
            list.classes.append(ref)
        }
        for ref in extra.variants where !list.variants.contains(where: { $0.name == ref.name && $0.source == ref.source }) {
            list.variants.append(ref)
        }
        return list
    }
}
