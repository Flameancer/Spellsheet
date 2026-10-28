import Foundation
import SpellsheetCore

enum Check {
    nonisolated(unsafe) static var failed = 0

    static func fail(_ message: String, file: StaticString = #file, line: UInt = #line) {
        failed += 1
        print("FAIL \(file):\(line) \(message)")
    }

    static func equal<T: Equatable>(_ actual: T, _ expected: T, _ name: String, file: StaticString = #file, line: UInt = #line) {
        if actual != expected { fail("\(name): got \(actual), expected \(expected)", file: file, line: line) }
    }

    static func isTrue(_ value: Bool, _ name: String, file: StaticString = #file, line: UInt = #line) {
        if !value { fail(name, file: file, line: line) }
    }

    static func isNil<T>(_ value: T?, _ name: String, file: StaticString = #file, line: UInt = #line) {
        if value != nil { fail("\(name): expected nil, got \(String(describing: value))", file: file, line: line) }
    }
}

@main
struct SpellsheetChecks {
    static func main() async {
        castingMath()
        entryText()
        parser()
        engine()
        brewCatalog()
        if ProcessInfo.processInfo.environment["SPELLSHEET_LIVE"] == "1" {
            await live()
        }
        if Check.failed > 0 {
            print("\(Check.failed) check(s) failed")
            exit(1)
        }
        print("All checks passed")
    }
}

private func castingMath() {
    Check.equal(CastingMath.abilityModifier(8), -1, "mod 8")
    Check.equal(CastingMath.abilityModifier(9), -1, "mod 9")
    Check.equal(CastingMath.abilityModifier(10), 0, "mod 10")
    Check.equal(CastingMath.abilityModifier(11), 0, "mod 11")
    Check.equal(CastingMath.abilityModifier(16), 3, "mod 16")
    Check.equal(CastingMath.proficiency(totalLevel: 1), 2, "prof 1")
    Check.equal(CastingMath.proficiency(totalLevel: 4), 2, "prof 4")
    Check.equal(CastingMath.proficiency(totalLevel: 5), 3, "prof 5")
    Check.equal(CastingMath.proficiency(totalLevel: 9), 4, "prof 9")
    Check.equal(CastingMath.proficiency(totalLevel: 17), 6, "prof 17")
    Check.equal(CastingMath.proficiency(totalLevel: 30), 6, "prof 30")
    Check.equal(CastingMath.saveDC(proficiency: 3, modifier: 4), 15, "dc")
    Check.equal(CastingMath.attackBonus(proficiency: 3, modifier: 4), 7, "attack")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 1, progression: "full"), 1, "full 1")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 5, progression: "full"), 3, "full 5")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 1, progression: "1/2"), 0, "half 1")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 2, progression: "1/2"), 1, "half 2")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 1, progression: "artificer"), 1, "artificer 1")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 3, progression: "1/3"), 1, "third 3")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 7, progression: "1/3"), 2, "third 7")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 5, progression: "pact"), 3, "pact 5")
    Check.equal(CastingMath.maxSpellLevel(classLevel: 11, progression: "pact"), 6, "pact 11")
    Check.equal(CastingMath.casterLevelContribution(classLevel: 5, progression: "full"), 5, "contrib full")
    Check.equal(CastingMath.casterLevelContribution(classLevel: 2, progression: "1/2"), 1, "contrib half")
    Check.equal(CastingMath.casterLevelContribution(classLevel: 1, progression: "1/2"), 0, "contrib half 1")
    Check.equal(CastingMath.casterLevelContribution(classLevel: 1, progression: "artificer"), 1, "contrib art")
    Check.equal(CastingMath.casterLevelContribution(classLevel: 5, progression: "pact"), 0, "contrib pact")
    Check.equal(Array(CastingMath.spellSlots(casterLevel: 6)[1...3]), [4, 3, 3], "slots 6")
    Check.equal(CastingMath.pactSlotCount(classLevel: 5), 2, "pact count")
    Check.equal(CastingMath.pactSlotLevel(classLevel: 5), 3, "pact level")
    Check.equal(CastingMath.preparedCount(formula: "<$level$> + <$int_mod$>", level: 1, modifier: 3), 4, "prep wizard")
    Check.equal(CastingMath.preparedCount(formula: "<$level$> / 2 + <$cha_mod$>", level: 5, modifier: 3), 5, "prep paladin")
    Check.equal(CastingMath.preparedCount(formula: "<$level$> + <$int_mod$>", level: 1, modifier: -1), 1, "prep minimum")
}

private func entryText() {
    Check.equal(
        EntryText.plain("increases by {@scaledamage 8d6|3-9|1d6} for each slot"),
        "increases by 1d6 for each slot",
        "scaledamage"
    )
    Check.equal(
        EntryText.plain("{@note Additional {@filter animal form choices|bestiary|Miscellaneous=Familiar} may exist.}"),
        "Additional animal form choices may exist.",
        "nested tags"
    )
    Check.equal(EntryText.plain("{@condition blinded||blind}"), "blind", "condition")
    Check.equal(EntryText.plain("{@hit +8} to hit"), "+8 to hit", "hit")
    Check.equal(EntryText.plain("{@dice 1d8} + your modifier"), "1d8 + your modifier", "dice")
    let blocks = EntryText.blocks(from: [
        "A mote of fire deals {@damage 1d10} fire damage.",
        [
            "type": "entries",
            "name": "Cantrip Upgrade",
            "entries": ["The damage increases at 5th level."],
        ] as [String: Any],
    ])
    let split = EntryText.splitHigherLevel(blocks)
    Check.equal(split.body.map(\.text), ["A mote of fire deals 1d10 fire damage."], "body split")
    Check.equal(split.higher.first?.text, "Cantrip Upgrade", "higher heading")
}

private func parser() {
    do {
        let json = """
        {"spell":[{
          "name":"Fireball","source":"PHB","page":241,"level":3,"school":"V",
          "time":[{"number":1,"unit":"action"}],
          "range":{"type":"point","distance":{"type":"feet","amount":150}},
          "components":{"v":true,"s":true,"m":{"text":"bat guano","cost":1000,"consume":true}},
          "duration":[{"type":"instant"}],
          "savingThrow":["dexterity"],
          "damageInflict":["fire"],
          "entries":["Each creature makes a Dexterity save and takes {@damage 8d6} fire damage."],
          "entriesHigherLevel":[{"type":"entries","name":"At Higher Levels","entries":[
            "The damage increases by {@scaledamage 8d6|3-9|1d6} for each slot level above 3rd."
          ]}]
        }]}
        """.data(using: .utf8)!
        guard let spell = try CatalogParser.spells(from: json).first else {
            Check.fail("missing fireball")
            return
        }
        Check.equal(spell.castingTime, "1 action", "time")
        Check.equal(spell.range, "150 feet", "range")
        Check.equal(spell.components, "V, S, M", "components")
        Check.equal(spell.material, "bat guano (10 gp, consumed)", "material")
        Check.equal(spell.duration, "Instantaneous", "duration")
        Check.equal(spell.savingThrows, ["Dexterity"], "save")
        Check.equal(spell.description.first?.text, "Each creature makes a Dexterity save and takes 8d6 fire damage.", "desc")
        Check.isTrue(spell.higherLevel.contains { $0.text.contains("1d6") }, "higher dice")
        Check.equal(spell.fiveEToolsURL?.absoluteString, "https://5e.tools/spells.html#fireball_phb", "url")

        let blessJSON = """
        {"spell":[{
          "name":"Bless","source":"PHB","level":1,"school":"E",
          "time":[{"number":1,"unit":"action"}],
          "range":{"type":"point","distance":{"type":"feet","amount":30}},
          "components":{"v":true,"s":true,"m":"holy water"},
          "duration":[{"type":"timed","duration":{"type":"minute","amount":1},"concentration":true}],
          "entries":["You bless up to three creatures."]
        }]}
        """.data(using: .utf8)!
        let bless = try CatalogParser.spells(from: blessJSON)[0]
        Check.isTrue(bless.concentration, "concentration")
        Check.equal(bless.duration, "Concentration, up to 1 minute", "conc duration")

        let lists = try CatalogParser.classLists(from: """
        {"PHB":{"Fireball":{"class":[{"name":"Wizard","source":"PHB"},{"name":"Sorcerer","source":"PHB"}]},
        "Absorb Elements":{"classVariant":[{"name":"Wizard","source":"PHB","definedInSource":"XGE"}]}}}
        """.data(using: .utf8)!)
        Check.equal(lists["fireball|PHB"]?.classes.map(\.name), ["Wizard", "Sorcerer"], "class list")
        Check.equal(lists["absorb elements|PHB"]?.variants.map(\.name), ["Wizard"], "variant list")

        let file = try CatalogParser.classFile(from: """
        {"class":[
          {"name":"Cleric","source":"PHB","edition":"classic","spellcastingAbility":"wis","casterProgression":"full",
           "preparedSpells":"<$level$> + <$wis_mod$>","cantripProgression":[3,3,3]},
          {"name":"Fighter","source":"PHB","edition":"classic"}
        ],
        "subclass":[
          {"name":"Life Domain","source":"PHB","className":"Cleric","classSource":"PHB",
           "additionalSpells":[{"prepared":{"1":["bless","cure wounds"],"3":["lesser restoration|phb"]}}]},
          {"name":"Circle of the Land","source":"PHB","className":"Druid","classSource":"PHB",
           "additionalSpells":[{"name":"Arctic","prepared":{"3":["spike growth"]}},{"name":"Coast","prepared":{"3":["misty step"]}}]},
          {"name":"Eldritch Knight","source":"PHB","className":"Fighter","classSource":"PHB",
           "spellcastingAbility":"int","casterProgression":"1/3",
           "additionalSpells":[{"known":{"3":["mage hand#c"]},"expanded":{"3":[{"all":"level=0|class=Wizard"}],"7":[{"all":"level=2|class=Wizard"}]}}]},
          {"name":"Life Domain","source":"PHB","className":"Cleric","classSource":"XPHB",
           "_copy":{"name":"Life Domain","source":"PHB","className":"Cleric","classSource":"PHB"}}
        ]}
        """.data(using: .utf8)!)
        let life = file.subclasses.first { $0.name == "Life Domain" }
        Check.equal(
            Set(life?.grants.compactMap(\.spellName) ?? []),
            ["bless", "cure wounds", "lesser restoration"],
            "life grants"
        )
        Check.equal(life?.grants.first { $0.spellName == "lesser restoration" }?.spellSource, "PHB", "life source")
        Check.equal(life?.grants.first { $0.spellName == "lesser restoration" }?.gate, .classLevel(3), "life gate")
        Check.equal(file.subclasses.first { $0.name == "Circle of the Land" }?.focuses, ["Arctic", "Coast"], "lands")
        let copied = CatalogParser.resolveCopies(file.subclasses, copies: file.copies)
            .first { $0.classSource == "XPHB" && $0.name == "Life Domain" }
        Check.equal(copied?.grants.count, 3, "copied grants")
    } catch {
        Check.fail("parser threw \(error)")
    }
}

private func engine() {
    do {
        let library = try sampleLibrary()
        let index = LibraryIndex(library: library)
        var character = CharacterSheet.makeNew()
        character.scores.intelligence = 18
        character.scores.wisdom = 16
        character.classes = [
            ClassPick(className: "Wizard", classSource: "PHB", level: 5),
            ClassPick(className: "Cleric", classSource: "PHB", level: 1, subclassName: "Life Domain", subclassSource: "PHB"),
        ]
        let profiles = SheetEngine.profiles(index: index, character: character)
        guard let wizard = profiles.first(where: { $0.className == "Wizard" }),
              let cleric = profiles.first(where: { $0.className == "Cleric" })
        else {
            Check.fail("missing profiles")
            return
        }
        Check.equal(wizard.ability, .intelligence, "wizard ability")
        Check.equal(wizard.modifier, 4, "wizard mod")
        Check.equal(wizard.proficiency, 3, "prof")
        Check.equal(wizard.saveDC, 15, "wizard dc")
        Check.equal(wizard.attackBonus, 7, "wizard attack")
        Check.equal(wizard.preparationLimit, 9, "wizard prepared")
        Check.isTrue(!wizard.preparationIsKnown, "wizard prepares")
        Check.equal(cleric.saveDC, 14, "cleric dc")
        Check.equal(cleric.attackBonus, 6, "cleric attack")
        Check.equal(cleric.preparationLimit, 4, "cleric prepared")
        let budget = SheetEngine.slots(index: index, character: character)
        Check.equal(budget.casterLevel, 6, "caster level")
        Check.equal(budget.count(forSpellLevel: 1), 4, "slot 1")
        Check.equal(budget.count(forSpellLevel: 3), 3, "slot 3")
        let access = SheetEngine.accessMap(index: index, character: character)
        Check.equal(access["Fireball|PHB"]?.reasons, ["Wizard"], "fireball class")
        Check.equal(access["Fireball|PHB"]?.castableNow, true, "fireball now")
        Check.equal(access["Cure Wounds|PHB"]?.alwaysPrepared, true, "cure always")
        Check.equal(access["Wish|PHB"]?.castableNow, false, "wish later")
        let sheet = SheetEngine.rows(index: index, character: character, mode: .sheet, query: "", includeHigherLevels: false)
        Check.equal(sheet.map(\.spell.name), ["Cure Wounds"], "sheet default")
        character.preparedIDs = ["Fireball|PHB", "Mage Hand|PHB"]
        let usage = SheetEngine.preparationUsage(for: wizard, index: index, character: character)
        Check.equal(usage.leveled, 1, "used leveled")
        Check.equal(usage.cantrips, 1, "used cantrips")
        Check.equal(
            SheetEngine.rows(index: index, character: character, mode: .sheet, query: "fire", includeHigherLevels: false).map(\.spell.name),
            ["Fireball"],
            "search"
        )
        var brew = HomebrewSpell.makeNew()
        brew.name = "Ashen Bolt"
        brew.level = 1
        brew.summary = "A bolt of ash."
        brew.classes = [ClassRef(name: "Wizard", source: "PHB")]
        let merged = LibraryIndex(library: library.addingHomebrew([brew]))
        Check.equal(
            SheetEngine.rows(index: merged, character: character, mode: .catalog, query: "ashen", includeHigherLevels: false).map(\.spell.name),
            ["Ashen Bolt"],
            "homebrew list"
        )

        var knight = CharacterSheet.makeNew()
        knight.scores.intelligence = 16
        knight.classes = [
            ClassPick(className: "Fighter", classSource: "PHB", level: 3, subclassName: "Eldritch Knight", subclassSource: "PHB"),
        ]
        let knightAccess = SheetEngine.accessMap(index: index, character: knight)
        Check.equal(knightAccess["Mage Hand|PHB"]?.alwaysPrepared, true, "ek hand")
        Check.equal(knightAccess["Shield|PHB"]?.castableNow, true, "ek shield")
        Check.isNil(knightAccess["Fireball|PHB"], "ek no fireball yet")
        Check.isNil(knightAccess["Cure Wounds|PHB"], "ek no cure")
        knight.classes[0].level = 13
        Check.equal(SheetEngine.accessMap(index: index, character: knight)["Fireball|PHB"]?.castableNow, true, "ek fireball 13")

        var higher = CharacterSheet.makeNew()
        higher.classes = [ClassPick(className: "Wizard", classSource: "PHB", level: 5)]
        Check.isTrue(
            SheetEngine.rows(index: index, character: higher, mode: .catalog, query: "wish", includeHigherLevels: false).isEmpty,
            "wish hidden"
        )
        Check.equal(
            SheetEngine.rows(index: index, character: higher, mode: .catalog, query: "wish", includeHigherLevels: true).map(\.spell.name),
            ["Wish"],
            "wish shown"
        )
        Check.isNil(SheetEngine.accessMap(index: index, character: higher)["Absorb Elements|XGE"], "variant off")
        higher.includeVariants = true
        Check.isTrue(SheetEngine.accessMap(index: index, character: higher)["Absorb Elements|XGE"] != nil, "variant on")

        var pact = CharacterSheet.makeNew()
        pact.scores.charisma = 18
        pact.classes = [
            ClassPick(className: "Warlock", classSource: "PHB", level: 5),
            ClassPick(className: "Wizard", classSource: "PHB", level: 1),
        ]
        let pactBudget = SheetEngine.slots(index: index, character: pact)
        Check.equal(pactBudget.casterLevel, 1, "pact caster level")
        Check.equal(pactBudget.count(forSpellLevel: 1), 2, "wizard slots beside pact")
        Check.equal(pactBudget.pactSlots, 2, "pact slots")
        Check.equal(pactBudget.pactLevel, 3, "pact slot level")
        let warlock = SheetEngine.profiles(index: index, character: pact).first { $0.className == "Warlock" }
        Check.equal(warlock?.ability, .charisma, "warlock cha")
        Check.equal(warlock?.saveDC, 15, "warlock dc")
        Check.equal(warlock?.maxSpellLevel, 3, "warlock max")
        Check.equal(warlock?.preparationIsKnown, true, "warlock known")
    } catch {
        Check.fail("engine threw \(error)")
    }
}

private func live() async {
    do {
        let library = try await CatalogClient().download { _ in }
        let index = LibraryIndex(library: library)
        guard let fireball = index.spell(name: "Fireball", source: "PHB") else {
            Check.fail("live fireball missing")
            return
        }
        Check.isTrue(!fireball.description.isEmpty, "live description")
        Check.isTrue(
            fireball.higherLevel.contains { $0.text.localizedCaseInsensitiveContains("1d6") || $0.text.localizedCaseInsensitiveContains("higher") },
            "live higher"
        )
        Check.isTrue(
            library.lists[fireball.listKey]?.classes.contains { $0.name == "Wizard" && $0.source == "PHB" } == true,
            "live wizard list"
        )
        let wizard = library.classes.first { $0.name == "Wizard" && $0.source == "PHB" }
        Check.equal(wizard?.spellcastingAbility, .intelligence, "live int")
        Check.equal(wizard?.casterProgression, "full", "live full")
        Check.isTrue(library.spells.count > 300, "live spell count \(library.spells.count)")
        Check.isTrue(library.classes.count > 10, "live class count \(library.classes.count)")
    } catch {
        Check.fail("live download failed: \(error)")
    }
}

private func brewCatalog() {
    do {
        let props = """
        {"spell":{"spell/Sample; Ashen.json":"spell","collection/Other; Tome.json":"collection"}}
        """.data(using: .utf8)!
        let meta = """
        {"Sample; Ashen.json":{"n":["Ashen Notes"],"a":["ASH"],"e":0},
         "Other; Tome.json":{"n":["Other Tome"],"a":["OT"],"e":1,"s":"wip"}}
        """.data(using: .utf8)!
        let listed = try BrewCatalog.entries(props: props, meta: meta)
        Check.equal(listed.map(\.title), ["Ashen Notes", "Other Tome"], "brew titles")
        Check.equal(listed.first { $0.title == "Other Tome" }?.edition, "2024", "brew edition")
        Check.equal(listed.first { $0.title == "Other Tome" }?.kind, "collection", "brew kind")

        let file = """
        {"_meta":{"sources":[{"json":"TestBrew","full":"Test Brew","abbreviation":"TB"}]},
         "spell":[
           {"name":"Banishing Shot","source":"TestBrew","level":1,"school":"A",
            "time":[{"number":1,"unit":"bonus"}],
            "range":{"type":"point","distance":{"type":"self"}},
            "components":{"s":true},"duration":[{"type":"instant"}],
            "entries":["You banish the target."],
            "classes":{"fromClassList":[{"name":"Wizard","source":"PHB"}]}},
           {"name":"Bare Spark","source":"TestBrew","level":0,"school":"V",
            "entries":["A spark."],
            "classes":{"fromClassList":["Wizard"]}},
           {"name":"Ash Copy","source":"TestBrew","level":3,"school":"V",
            "_copy":{"name":"Fireball","source":"PHB"},
            "classes":{"fromClassList":[{"name":"Wizard","source":"PHB"}]}},
           {"name":"Fireball","source":"PHB","level":3,"school":"V",
            "entries":["This replacement must not win."],
            "classes":{"fromClassList":[{"name":"Cleric","source":"PHB"}]}}
         ]}
        """.data(using: .utf8)!
        let document = try BrewCatalog.document(from: file, path: "spell/Sample; Ashen.json", title: "Ashen Notes", abbreviation: "ASH")
        Check.equal(document.spells.map(\.name).sorted(), ["Ash Copy", "Banishing Shot", "Bare Spark"], "brew spells")
        Check.equal(document.lists["fireball|PHB"]?.classes.map(\.name), ["Cleric"], "official list extra")

        let library = try sampleLibrary()
        let official = library.spells.first { $0.id == "Fireball|PHB" }
        let merged = library.addingBrews([document])
        Check.equal(merged.spells.filter { $0.name == "Fireball" }.count, 1, "official fireball stays")
        Check.equal(
            merged.spells.first { $0.id == "Fireball|PHB" }?.description,
            official?.description,
            "official text stays"
        )
        Check.equal(
            merged.spells.first { $0.name == "Ash Copy" }?.description,
            official?.description,
            "copy text"
        )
        var character = CharacterSheet.makeNew()
        character.classes = [ClassPick(className: "Wizard", classSource: "PHB", level: 5)]
        let names = SheetEngine.rows(
            index: LibraryIndex(library: merged),
            character: character,
            mode: .catalog,
            query: "",
            includeHigherLevels: false
        ).map(\.spell.name)
        Check.isTrue(names.contains("Banishing Shot"), "brew on wizard list")
        Check.isTrue(names.contains("Bare Spark"), "bare class name")
        Check.isTrue(names.contains("Ash Copy"), "copied spell on list")
        let cleric = CharacterSheet(
            id: UUID(),
            name: "Cleric",
            scores: .tens,
            classes: [ClassPick(className: "Cleric", classSource: "PHB", level: 5)],
            preparedIDs: [],
            expendedSlots: Array(repeating: 0, count: 10),
            expendedPact: 0,
            includeVariants: false
        )
        Check.isTrue(
            SheetEngine.accessMap(index: LibraryIndex(library: merged), character: cleric)["Fireball|PHB"] != nil,
            "brew can add a class"
        )
    } catch {
        Check.fail("brew catalog threw \(error)")
    }
}

private func sampleLibrary() throws -> Library {
    let spells = try CatalogParser.spells(from: """
    {"spell":[
      {"name":"Mage Hand","source":"PHB","level":0,"school":"C","time":[{"number":1,"unit":"action"}],
       "range":{"type":"point","distance":{"type":"feet","amount":30}},
       "components":{"v":true,"s":true},"duration":[{"type":"instant"}],"entries":["A spectral hand."]},
      {"name":"Shield","source":"PHB","level":1,"school":"A","time":[{"number":1,"unit":"reaction","condition":"when you are hit"}],
       "range":{"type":"point","distance":{"type":"self"}},
       "components":{"v":true,"s":true},"duration":[{"type":"timed","duration":{"type":"round","amount":1}}],
       "entries":["An invisible barrier."]},
      {"name":"Cure Wounds","source":"PHB","level":1,"school":"V","time":[{"number":1,"unit":"action"}],
       "range":{"type":"point","distance":{"type":"touch"}},
       "components":{"v":true,"s":true},"duration":[{"type":"instant"}],
       "entries":["A creature regains {@dice 1d8} + your spellcasting ability modifier."],
       "entriesHigherLevel":[{"type":"entries","name":"At Higher Levels","entries":["Healing increases by {@scaledice 1d8|1-9|1d8}."]}]},
      {"name":"Fireball","source":"PHB","level":3,"school":"V","time":[{"number":1,"unit":"action"}],
       "range":{"type":"point","distance":{"type":"feet","amount":150}},
       "components":{"v":true,"s":true,"m":"sulfur"},"duration":[{"type":"instant"}],
       "savingThrow":["dexterity"],"entries":["{@damage 8d6} fire damage."],
       "entriesHigherLevel":[{"type":"entries","name":"At Higher Levels","entries":["+{@scaledamage 8d6|3-9|1d6} per slot."]}]},
      {"name":"Wish","source":"PHB","level":9,"school":"C","time":[{"number":1,"unit":"action"}],
       "range":{"type":"point","distance":{"type":"self"}},
       "components":{"v":true},"duration":[{"type":"instant"}],"entries":["You alter reality."]},
      {"name":"Absorb Elements","source":"XGE","level":1,"school":"A","time":[{"number":1,"unit":"reaction"}],
       "range":{"type":"point","distance":{"type":"self"}},
       "components":{"s":true},"duration":[{"type":"timed","duration":{"type":"round","amount":1}}],
       "entries":["You absorb energy."]}
    ]}
    """.data(using: .utf8)!)
    let file = try CatalogParser.classFile(from: """
    {"class":[
      {"name":"Wizard","source":"PHB","edition":"classic","spellcastingAbility":"int","casterProgression":"full",
       "preparedSpells":"<$level$> + <$int_mod$>","cantripProgression":[3,3,3,4,4,4,4,4,4,5]},
      {"name":"Cleric","source":"PHB","edition":"classic","spellcastingAbility":"wis","casterProgression":"full",
       "preparedSpells":"<$level$> + <$wis_mod$>","cantripProgression":[3,3,3]},
      {"name":"Fighter","source":"PHB","edition":"classic"},
      {"name":"Warlock","source":"PHB","edition":"classic","spellcastingAbility":"cha","casterProgression":"pact",
       "spellsKnownProgression":[2,3,4,5,6,7,8,9,10,10],"cantripProgression":[2,2,2,3,3]}
    ],
    "subclass":[
      {"name":"Life Domain","source":"PHB","className":"Cleric","classSource":"PHB",
       "additionalSpells":[{"prepared":{"1":["bless","cure wounds"]}}]},
      {"name":"Eldritch Knight","source":"PHB","className":"Fighter","classSource":"PHB",
       "spellcastingAbility":"int","casterProgression":"1/3",
       "spellsKnownProgression":[0,0,3],"cantripProgression":[0,0,2],
       "additionalSpells":[{"known":{"3":["mage hand#c"]},"expanded":{
         "3":[{"all":"level=0|class=Wizard"},{"all":"level=1|class=Wizard"}],
         "13":[{"all":"level=3|class=Wizard"}]}}]}
    ]}
    """.data(using: .utf8)!)
    let lists = try CatalogParser.classLists(from: """
    {"PHB":{
      "Mage Hand":{"class":[{"name":"Wizard","source":"PHB"}]},
      "Shield":{"class":[{"name":"Wizard","source":"PHB"}]},
      "Cure Wounds":{"class":[{"name":"Cleric","source":"PHB"}]},
      "Fireball":{"class":[{"name":"Wizard","source":"PHB"},{"name":"Sorcerer","source":"PHB"}]},
      "Wish":{"class":[{"name":"Wizard","source":"PHB"}]}
    },
    "XGE":{"Absorb Elements":{"classVariant":[{"name":"Wizard","source":"PHB"}]}}}
    """.data(using: .utf8)!)
    return Library(
        fetchedAt: Date(),
        sourceNames: ["PHB": "Player's Handbook (2014)", "XGE": "Xanathar's Guide to Everything"],
        classes: file.classes,
        subclasses: file.subclasses,
        spells: spells,
        lists: lists
    )
}
