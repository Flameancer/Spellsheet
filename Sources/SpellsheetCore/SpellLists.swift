import Foundation

public struct SpellAccess: Sendable, Equatable {
    public var alwaysPrepared: Bool
    public var castableNow: Bool
    public var reasons: [String]

    public init(alwaysPrepared: Bool, castableNow: Bool, reasons: [String]) {
        self.alwaysPrepared = alwaysPrepared
        self.castableNow = castableNow
        self.reasons = reasons
    }
}

public struct SheetRow: Identifiable, Sendable {
    public var spell: Spell
    public var access: SpellAccess
    public var prepared: Bool

    public var id: String { spell.id }
    public var onSheet: Bool { prepared || access.alwaysPrepared }
}

public extension SheetEngine {
    static func accessMap(index: LibraryIndex, character: CharacterSheet) -> [String: SpellAccess] {
        let profiles = profiles(index: index, character: character)
        var map: [String: SpellAccess] = [:]

        func add(spell: Spell, reason: String, always: Bool, castableNow: Bool) {
            var current = map[spell.id] ?? SpellAccess(alwaysPrepared: false, castableNow: false, reasons: [])
            if !current.reasons.contains(reason) { current.reasons.append(reason) }
            if always { current.alwaysPrepared = true }
            if castableNow { current.castableNow = true }
            map[spell.id] = current
        }

        for pick in character.classes {
            guard let classDef = classDefinition(index: index, pick: pick),
                  let profile = profiles.first(where: { $0.id == pick.id })
            else { continue }
            let subclass = subclassDefinition(index: index, pick: pick)
            for spell in index.library.spells {
                guard let list = index.library.lists[spell.listKey] else { continue }
                let onBase = list.classes.contains { $0.name == classDef.name && $0.source == classDef.source }
                let onVariant = character.includeVariants && list.variants.contains {
                    $0.name == classDef.name && $0.source == classDef.source
                }
                guard onBase || onVariant else { continue }
                let castable = spell.level == 0 || spell.level <= profile.maxSpellLevel
                add(spell: spell, reason: classDef.name, always: false, castableNow: castable)
            }

            for grant in subclass?.grants ?? [] {
                if let focus = grant.focus, focus != pick.focus { continue }
                guard grant.gate.isOpen(classLevel: pick.level, maxSpellLevel: profile.maxSpellLevel) else { continue }
                if grant.isFilter {
                    guard let className = grant.filterClassName else { continue }
                    let sources = classSources(
                        named: className,
                        explicit: grant.filterClassSource,
                        edition: classDef.edition,
                        in: index.library
                    )
                    for spell in index.library.spells {
                        if let filterLevel = grant.filterLevel, spell.level != filterLevel { continue }
                        guard let list = index.library.lists[spell.listKey] else { continue }
                        let matches = list.classes.contains { ref in
                            ref.name == className && (sources.isEmpty || sources.contains(ref.source))
                        }
                        guard matches else { continue }
                        let castable = spell.level == 0 || spell.level <= profile.maxSpellLevel
                        add(
                            spell: spell,
                            reason: subclass?.name ?? classDef.name,
                            always: grant.kind == .alwaysPrepared && castable,
                            castableNow: castable
                        )
                    }
                } else if let name = grant.spellName,
                          let spell = index.resolve(
                            name: name,
                            source: grant.spellSource,
                            edition: classDef.edition,
                            classSource: classDef.source
                          ) {
                    let castable = spell.level == 0 || spell.level <= profile.maxSpellLevel
                    add(
                        spell: spell,
                        reason: subclass?.shortName ?? subclass?.name ?? classDef.name,
                        always: grant.kind == .alwaysPrepared && castable,
                        castableNow: castable
                    )
                }
            }
        }
        return map
    }

    static func rows(
        index: LibraryIndex,
        character: CharacterSheet,
        mode: ListMode,
        query: String,
        includeHigherLevels: Bool
    ) -> [SheetRow] {
        let access = accessMap(index: index, character: character)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prepared = Set(character.preparedIDs)
        var rows: [SheetRow] = []
        for spell in index.library.spells {
            guard let entry = access[spell.id] else { continue }
            let isPrepared = prepared.contains(spell.id)
            if !entry.castableNow && !includeHigherLevels && !isPrepared && !entry.alwaysPrepared { continue }
            if mode == .sheet && !isPrepared && !entry.alwaysPrepared { continue }
            if !needle.isEmpty {
                let haystack = "\(spell.name) \(spell.schoolName) \(spell.source)".lowercased()
                if !haystack.contains(needle) { continue }
            }
            rows.append(SheetRow(spell: spell, access: entry, prepared: isPrepared))
        }
        return rows
    }

    /// Spells on more than one list count toward the earliest class on the character.
    static func preparationUsage(
        for profile: CastingProfile,
        index: LibraryIndex,
        character: CharacterSheet
    ) -> (cantrips: Int, leveled: Int) {
        let casting = profiles(index: index, character: character)
        let access = accessMap(index: index, character: character)
        var cantrips = 0
        var leveled = 0
        for id in character.preparedIDs {
            guard let spell = index.spell(id: id) else { continue }
            if access[id]?.alwaysPrepared == true { continue }
            guard let owner = casting.first(where: { owns($0, spellID: id, access: access) }),
                  owner.id == profile.id
            else { continue }
            if spell.level == 0 { cantrips += 1 } else { leveled += 1 }
        }
        return (cantrips, leveled)
    }

    private static func owns(_ profile: CastingProfile, spellID: String, access: [String: SpellAccess]) -> Bool {
        guard let reasons = access[spellID]?.reasons else { return false }
        if reasons.contains(profile.className) { return true }
        if let subclassName = profile.subclassName, reasons.contains(subclassName) { return true }
        return false
    }

    private static func classSources(
        named name: String,
        explicit source: String?,
        edition: String,
        in library: Library
    ) -> Set<String> {
        if let source { return [source] }
        return Set(library.classes.filter { $0.name == name && $0.edition == edition }.map(\.source))
    }
}
