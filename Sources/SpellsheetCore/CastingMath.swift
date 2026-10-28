import Foundation

public enum CastingMath {
    public static func abilityModifier(_ score: Int) -> Int {
        Int(floor(Double(score - 10) / 2.0))
    }

    public static func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    /// Proficiency bonus for a character level. Levels above 20 stay at +6.
    public static func proficiency(totalLevel: Int) -> Int {
        let level = min(max(totalLevel, 1), 20)
        return 2 + (level - 1) / 4
    }

    public static func saveDC(proficiency: Int, modifier: Int) -> Int {
        8 + proficiency + modifier
    }

    public static func attackBonus(proficiency: Int, modifier: Int) -> Int {
        proficiency + modifier
    }

    /// Highest leveled spell this class can cast. Cantrips are separate.
    public static func maxSpellLevel(classLevel: Int, progression: String?) -> Int {
        let level = max(classLevel, 0)
        switch progression {
        case "full":
            return min(9, (level + 1) / 2)
        case "1/2":
            guard level >= 2 else { return 0 }
            return min(5, (level + 3) / 4)
        case "artificer":
            return min(5, (level + 3) / 4)
        case "1/3":
            guard level >= 3 else { return 0 }
            return min(4, (level + 5) / 6)
        case "pact":
            return max(pactSlotLevel(classLevel: level), mysticArcanumLevel(classLevel: level))
        default:
            return 0
        }
    }

    public static func pactSlotLevel(classLevel: Int) -> Int {
        switch classLevel {
        case ..<1: 0
        case 1, 2: 1
        case 3, 4: 2
        case 5, 6: 3
        case 7, 8: 4
        default: 5
        }
    }

    public static func pactSlotCount(classLevel: Int) -> Int {
        switch classLevel {
        case ..<1: 0
        case 1: 1
        case 2...10: 2
        case 11...16: 3
        default: 4
        }
    }

    public static func mysticArcanumLevel(classLevel: Int) -> Int {
        switch classLevel {
        case 17...: 9
        case 15...16: 8
        case 13...14: 7
        case 11...12: 6
        default: 0
        }
    }

    /// Multiclass caster level contributed by one class. Pact magic contributes 0.
    public static func casterLevelContribution(classLevel: Int, progression: String?) -> Int {
        switch progression {
        case "full": classLevel
        case "1/2": classLevel / 2
        case "artificer": (classLevel + 1) / 2
        case "1/3": classLevel / 3
        default: 0
        }
    }

    /// Standard multiclass spell slot table, index 0 unused. Values are slot counts for levels 1...9.
    public static func spellSlots(casterLevel: Int) -> [Int] {
        let table: [[Int]] = [
            [],
            [2],
            [3],
            [4, 2],
            [4, 3],
            [4, 3, 2],
            [4, 3, 3],
            [4, 3, 3, 1],
            [4, 3, 3, 2],
            [4, 3, 3, 3, 1],
            [4, 3, 3, 3, 2],
            [4, 3, 3, 3, 2, 1],
            [4, 3, 3, 3, 2, 1],
            [4, 3, 3, 3, 2, 1, 1],
            [4, 3, 3, 3, 2, 1, 1],
            [4, 3, 3, 3, 2, 1, 1, 1],
            [4, 3, 3, 3, 2, 1, 1, 1],
            [4, 3, 3, 3, 2, 1, 1, 1, 1],
            [4, 3, 3, 3, 3, 1, 1, 1, 1],
            [4, 3, 3, 3, 3, 2, 1, 1, 1],
            [4, 3, 3, 3, 3, 2, 2, 1, 1],
        ]
        let level = min(max(casterLevel, 0), table.count - 1)
        var slots = Array(repeating: 0, count: 10)
        for (index, count) in table[level].enumerated() {
            slots[index + 1] = count
        }
        return slots
    }

    public static func progressionValue(_ values: [Int]?, level: Int) -> Int? {
        guard let values, !values.isEmpty, level >= 1 else { return nil }
        return values[min(level, values.count) - 1]
    }

    /// Evaluates a 5e.tools prepared-spell formula such as `<$level$> / 2 + <$cha_mod$>`.
    public static func preparedCount(formula: String, level: Int, modifier: Int) -> Int {
        var expression = formula
            .replacingOccurrences(of: "<$level$>", with: "\(level)")
        for ability in Ability.allCases {
            expression = expression.replacingOccurrences(of: "<$\(ability.rawValue)_mod$>", with: "\(modifier)")
        }
        let value = evaluate(expression) ?? (level + modifier)
        return max(1, value)
    }

    public static func evaluate(_ expression: String) -> Int? {
        var parser = FormulaParser(expression.filter { !$0.isWhitespace })
        guard let value = parser.parseExpression(), parser.isAtEnd else { return nil }
        return value
    }
}

private struct FormulaParser {
    let characters: [Character]
    var index = 0

    init(_ expression: String) {
        characters = Array(expression)
    }

    var isAtEnd: Bool { index >= characters.count }

    mutating func parseExpression() -> Int? {
        guard var value = parseTerm() else { return nil }
        while let op = peek(), op == "+" || op == "-" {
            index += 1
            guard let term = parseTerm() else { return nil }
            value = op == "+" ? value + term : value - term
        }
        return value
    }

    mutating func parseTerm() -> Int? {
        guard var value = parseNumber() else { return nil }
        while let op = peek(), op == "/" || op == "*" {
            index += 1
            guard let number = parseNumber(), number != 0 || op != "/" else { return nil }
            value = op == "/" ? value / number : value * number
        }
        return value
    }

    mutating func parseNumber() -> Int? {
        guard !isAtEnd else { return nil }
        var sign = 1
        if characters[index] == "-" {
            sign = -1
            index += 1
        } else if characters[index] == "+" {
            index += 1
        }
        guard !isAtEnd, characters[index].isNumber else { return nil }
        var number = 0
        while !isAtEnd, characters[index].isNumber {
            number = number * 10 + Int(String(characters[index]))!
            index += 1
        }
        return sign * number
    }

    func peek() -> Character? {
        isAtEnd ? nil : characters[index]
    }
}

public struct SlotBudget: Sendable, Equatable {
    public var casterLevel: Int
    public var slots: [Int]
    public var pactSlots: Int
    public var pactLevel: Int
    public var contributions: [String]

    public init(casterLevel: Int, slots: [Int], pactSlots: Int, pactLevel: Int, contributions: [String]) {
        self.casterLevel = casterLevel
        self.slots = slots
        self.pactSlots = pactSlots
        self.pactLevel = pactLevel
        self.contributions = contributions
    }

    public func count(forSpellLevel level: Int) -> Int {
        guard level >= 1, level < slots.count else { return 0 }
        return slots[level]
    }
}

public struct CastingProfile: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var className: String
    public var classSource: String
    public var subclassName: String?
    public var focus: String?
    public var level: Int
    public var ability: Ability?
    public var abilityScore: Int
    public var modifier: Int
    public var proficiency: Int
    public var saveDC: Int
    public var attackBonus: Int
    public var progression: String?
    public var maxSpellLevel: Int
    public var cantripLimit: Int?
    public var preparationLimit: Int?
    public var preparationIsKnown: Bool
    public var edition: String

    public var title: String {
        var text = "\(className) \(level)"
        if let subclassName { text += " · \(subclassName)" }
        return text
    }
}

public enum SheetEngine {
    public static func profiles(index: LibraryIndex, character: CharacterSheet) -> [CastingProfile] {
        let proficiency = CastingMath.proficiency(totalLevel: character.totalLevel)
        return character.classes.compactMap { pick in
            guard let classDef = classDefinition(index: index, pick: pick) else { return nil }
            let subclass = subclassDefinition(index: index, pick: pick)
            let subclassIsCaster = classDef.casterProgression == nil && subclass?.casterProgression != nil
            let progression = classDef.casterProgression ?? subclass?.casterProgression
            let ability = resolvedAbility(pick: pick, classDef: classDef, subclass: subclass, subclassIsCaster: subclassIsCaster)
            let score = ability.map { character.scores.score($0) } ?? 10
            let modifier = ability == nil ? 0 : CastingMath.abilityModifier(score)
            let maxLevel = CastingMath.maxSpellLevel(classLevel: pick.level, progression: progression)
            let cantrips = CastingMath.progressionValue(
                pickProgression(classDef.cantripProgression, subclass?.cantripProgression, subclassIsCaster: subclassIsCaster),
                level: pick.level
            )
            let (limit, known) = preparationLimit(
                classDef: classDef,
                subclass: subclass,
                subclassIsCaster: subclassIsCaster,
                level: pick.level,
                modifier: modifier,
                maxSpellLevel: maxLevel
            )
            guard ability != nil || progression != nil || !(subclass?.grants.isEmpty ?? true) else {
                return nil
            }
            return CastingProfile(
                id: pick.id,
                className: classDef.name,
                classSource: classDef.source,
                subclassName: subclass?.name,
                focus: pick.focus,
                level: pick.level,
                ability: ability,
                abilityScore: score,
                modifier: modifier,
                proficiency: proficiency,
                saveDC: CastingMath.saveDC(proficiency: proficiency, modifier: modifier),
                attackBonus: CastingMath.attackBonus(proficiency: proficiency, modifier: modifier),
                progression: progression,
                maxSpellLevel: maxLevel,
                cantripLimit: cantrips,
                preparationLimit: limit,
                preparationIsKnown: known,
                edition: classDef.edition
            )
        }
    }

    public static func slots(index: LibraryIndex, character: CharacterSheet) -> SlotBudget {
        var casterLevel = 0
        var pactLevel = 0
        var notes: [String] = []
        for pick in character.classes {
            guard let classDef = classDefinition(index: index, pick: pick) else { continue }
            let subclass = subclassDefinition(index: index, pick: pick)
            let progression = classDef.casterProgression ?? subclass?.casterProgression
            if progression == "pact" {
                pactLevel += pick.level
                notes.append("\(classDef.name) \(pick.level) uses pact magic")
            } else {
                let contribution = CastingMath.casterLevelContribution(classLevel: pick.level, progression: progression)
                if contribution > 0 {
                    casterLevel += contribution
                    notes.append("\(classDef.name) \(pick.level) counts as \(contribution)")
                }
            }
        }
        casterLevel = min(casterLevel, 20)
        pactLevel = min(pactLevel, 20)
        return SlotBudget(
            casterLevel: casterLevel,
            slots: CastingMath.spellSlots(casterLevel: casterLevel),
            pactSlots: CastingMath.pactSlotCount(classLevel: pactLevel),
            pactLevel: CastingMath.pactSlotLevel(classLevel: pactLevel),
            contributions: notes
        )
    }

    public static func classDefinition(index: LibraryIndex, pick: ClassPick) -> ClassDefinition? {
        index.library.classes.first { $0.name == pick.className && $0.source == pick.classSource }
    }

    public static func subclassDefinition(index: LibraryIndex, pick: ClassPick) -> SubclassDefinition? {
        guard let name = pick.subclassName, let source = pick.subclassSource else { return nil }
        return index.library.subclasses.first {
            $0.name == name && $0.source == source && $0.className == pick.className && $0.classSource == pick.classSource
        }
    }

    public static func subclasses(for classDef: ClassDefinition, in library: Library) -> [SubclassDefinition] {
        library.subclasses
            .filter { $0.className == classDef.name && $0.classSource == classDef.source }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func resolvedAbility(
        pick: ClassPick,
        classDef: ClassDefinition,
        subclass: SubclassDefinition?,
        subclassIsCaster: Bool
    ) -> Ability? {
        if let override = pick.abilityOverride { return override }
        if subclassIsCaster { return subclass?.spellcastingAbility ?? classDef.spellcastingAbility }
        return classDef.spellcastingAbility ?? subclass?.spellcastingAbility
    }

    private static func pickProgression(_ base: [Int]?, _ sub: [Int]?, subclassIsCaster: Bool) -> [Int]? {
        subclassIsCaster ? (sub ?? base) : (base ?? sub)
    }

    private static func preparationLimit(
        classDef: ClassDefinition,
        subclass: SubclassDefinition?,
        subclassIsCaster: Bool,
        level: Int,
        modifier: Int,
        maxSpellLevel: Int
    ) -> (Int?, Bool) {
        guard maxSpellLevel > 0 || (subclass?.cantripProgression ?? classDef.cantripProgression) != nil else {
            return (nil, false)
        }
        if subclassIsCaster, let progression = subclass?.preparedProgression,
           let count = CastingMath.progressionValue(progression, level: level) {
            return (count, false)
        }
        if let formula = classDef.preparedFormula, maxSpellLevel > 0 {
            return (CastingMath.preparedCount(formula: formula, level: level, modifier: modifier), false)
        }
        if let progression = pickProgression(classDef.preparedProgression, subclass?.preparedProgression, subclassIsCaster: subclassIsCaster),
           let count = CastingMath.progressionValue(progression, level: level) {
            return (count, false)
        }
        if let progression = pickProgression(classDef.spellsKnownProgression, subclass?.spellsKnownProgression, subclassIsCaster: subclassIsCaster),
           let count = CastingMath.progressionValue(progression, level: level) {
            return (count, true)
        }
        return (nil, false)
    }
}
