import Foundation
import Observation
import SpellsheetCore

enum SettingsTab: String, CaseIterable, Identifiable {
    case appearance
    case repository
    case spells

    var id: String { rawValue }
}

@MainActor
enum AppStore {
    static let shared = AppModel()
}

@MainActor
@Observable
final class AppModel {
    var characters: [CharacterSheet] = []
    var character = CharacterSheet.makeNew()
    var library: Library?
    var index: LibraryIndex?
    var loadMessage = "Loading the 5e.tools spell and class data"
    var isLoading = false
    var errorMessage: String?
    var selectedSpellID: String?
    var listMode: ListMode = .sheet
    var query = ""
    var includeHigherLevels = false
    var showingAddClass = false
    var confirmingDelete = false
    var classSearch = ""
    var classEdition = "All"
    var showingSettings = false
    var settingsTab: SettingsTab = .repository
    var colorTheme: AppThemeID = AppModel.loadColorTheme() {
        didSet { AppModel.saveColorTheme(colorTheme) }
    }
    var homebrew: [HomebrewSpell] = []
    var homebrewDraft: HomebrewSpell?
    var settingsClassQuery = ""
    var brewCatalog: [BrewCatalogEntry] = []
    var brewCatalogMessage = ""
    var brewCatalogLoading = false
    var brewQuery = ""
    var addedBrews: [BrewDocument] = []
    var brewAddingPath: String?
    private var brewCatalogFetched = false
    private var brewCatalogTask: Task<Void, Never>?

    private var didBoot = false
    private static let colorThemeKey = "colorTheme"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func bootstrap() {
        guard !didBoot else { return }
        didBoot = true
        loadCharacters()
        loadHomebrew()
        loadBrews()
        if let cached = loadLibrary(), cached.schema == librarySchema {
            library = cached
            publishIndex()
            loadMessage = "Cached \(cached.spells.count) spells · \(cached.fetchedAt.formatted(date: .abbreviated, time: .shortened))"
            if Date().timeIntervalSince(cached.fetchedAt) > 60 * 60 * 24 * 7 {
                refresh()
            }
        } else {
            refresh()
        }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        loadMessage = "Contacting the 5e.tools dataset"
        Task {
            do {
                let downloaded = try await CatalogClient().download { message in
                    Task { @MainActor in
                        self.loadMessage = message
                    }
                }
                library = downloaded
                publishIndex()
                try saveLibrary(downloaded)
                loadMessage = "Loaded \(downloaded.spells.count) spells and \(downloaded.classes.count) classes"
                clampExpended()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func persistActive() {
        if let existing = characters.firstIndex(where: { $0.id == character.id }) {
            characters[existing] = character
        } else {
            characters.append(character)
        }
        saveCharacters()
    }

    func showCharacter(_ id: UUID) {
        guard id != character.id else { return }
        persistActive()
        guard let next = characters.first(where: { $0.id == id }) else { return }
        character = next
        selectedSpellID = nil
    }

    func newCharacter() {
        persistActive()
        var fresh = CharacterSheet.makeNew()
        fresh.name = unusedName(startingAt: "New Caster")
        characters.append(fresh)
        character = fresh
        selectedSpellID = nil
        saveCharacters()
    }

    func deleteActive() {
        characters.removeAll { $0.id == character.id }
        if characters.isEmpty {
            character = .makeNew()
            characters = [character]
        } else {
            character = characters[0]
        }
        selectedSpellID = nil
        saveCharacters()
    }

    func setScore(_ ability: Ability, _ score: Int) {
        var scores = character.scores
        scores.set(ability, score)
        character.scores = scores
    }

    func addClass(_ definition: ClassDefinition) {
        guard !character.classes.contains(where: { $0.className == definition.name && $0.classSource == definition.source }) else {
            return
        }
        character.classes.append(ClassPick(className: definition.name, classSource: definition.source, level: 1))
        clampExpended()
    }

    func removeClass(_ id: UUID) {
        character.classes.removeAll { $0.id == id }
        clampExpended()
    }

    func setLevel(_ id: UUID, _ level: Int) {
        guard let index = character.classes.firstIndex(where: { $0.id == id }) else { return }
        character.classes[index].level = min(20, max(1, level))
        clampExpended()
    }

    func setSubclass(_ id: UUID, name: String?, source: String?) {
        guard let index = character.classes.firstIndex(where: { $0.id == id }) else { return }
        character.classes[index].subclassName = name
        character.classes[index].subclassSource = source
        character.classes[index].focus = nil
    }

    func setFocus(_ id: UUID, _ focus: String?) {
        guard let index = character.classes.firstIndex(where: { $0.id == id }) else { return }
        character.classes[index].focus = focus
    }

    func setAbility(_ id: UUID, _ ability: Ability?) {
        guard let index = character.classes.firstIndex(where: { $0.id == id }) else { return }
        character.classes[index].abilityOverride = ability
    }

    var preparationWord: String {
        guard let index else { return "Prepared" }
        let profiles = SheetEngine.profiles(index: index, character: character)
        let casters = profiles.filter { $0.preparationLimit != nil || $0.cantripLimit != nil }
        if !casters.isEmpty && casters.allSatisfy(\.preparationIsKnown) { return "Known" }
        return "Prepared"
    }

    func addHomebrew() {
        commitHomebrewDraft()
        var spell = HomebrewSpell.makeNew()
        spell.name = unusedHomebrewName("New Spell")
        homebrew.append(spell)
        homebrewDraft = spell
        saveHomebrew()
        publishIndex()
    }

    func deleteHomebrew(_ id: UUID) {
        guard let existing = homebrew.first(where: { $0.id == id }) else { return }
        homebrew.removeAll { $0.id == id }
        if homebrewDraft?.id == id { homebrewDraft = homebrew.first }
        rewritePreparedID(from: existing.spellID, to: nil)
        saveHomebrew()
        publishIndex()
    }

    func selectHomebrew(_ id: UUID?) {
        commitHomebrewDraft()
        homebrewDraft = homebrew.first { $0.id == id }
    }

    func commitHomebrewDraft() {
        guard var draft = homebrewDraft,
              let index = homebrew.firstIndex(where: { $0.id == draft.id })
        else { return }
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.level = min(9, max(0, draft.level))
        if draft.name.isEmpty { draft.name = homebrew[index].name }
        if homebrew.contains(where: { $0.id != draft.id && $0.name.caseInsensitiveCompare(draft.name) == .orderedSame }) {
            draft.name = homebrew[index].name
        }
        let previous = homebrew[index].spellID
        homebrew[index] = draft
        homebrewDraft = draft
        if previous != draft.spellID {
            rewritePreparedID(from: previous, to: draft.spellID)
        }
        saveHomebrew()
        publishIndex()
    }

    func editHomebrewDraft(_ mutate: (inout HomebrewSpell) -> Void) {
        guard var draft = homebrewDraft else { return }
        mutate(&draft)
        homebrewDraft = draft
    }

    func togglePrepared(_ spellID: String) {
        if let index = character.preparedIDs.firstIndex(of: spellID) {
            character.preparedIDs.remove(at: index)
        } else {
            character.preparedIDs.append(spellID)
            selectedSpellID = spellID
        }
    }

    func changeSlot(level: Int, restore: Bool) {
        guard let index, (1...9).contains(level) else { return }
        normalizeSlotStorage()
        let cap = SheetEngine.slots(index: index, character: character).count(forSpellLevel: level)
        if restore {
            character.expendedSlots[level] = max(0, character.expendedSlots[level] - 1)
        } else if character.expendedSlots[level] < cap {
            character.expendedSlots[level] += 1
        }
    }

    func changePact(restore: Bool) {
        guard let index else { return }
        let cap = SheetEngine.slots(index: index, character: character).pactSlots
        if restore {
            character.expendedPact = max(0, character.expendedPact - 1)
        } else if character.expendedPact < cap {
            character.expendedPact += 1
        }
    }

    func longRest() {
        character.expendedSlots = Array(repeating: 0, count: 10)
        character.expendedPact = 0
    }

    func useSampleWizard() {
        guard let index else { return }
        guard index.library.classes.contains(where: { $0.name == "Wizard" && $0.source == "PHB" }) else { return }
        var sample = CharacterSheet.makeNew()
        sample.name = "Sample Wizard"
        sample.scores = AbilityScores(
            strength: 8, dexterity: 14, constitution: 14,
            intelligence: 16, wisdom: 12, charisma: 10
        )
        sample.classes = [ClassPick(className: "Wizard", classSource: "PHB", level: 5)]
        sample.preparedIDs = ["Fire Bolt", "Mage Hand", "Shield", "Magic Missile", "Misty Step", "Fireball"].compactMap {
            index.spell(name: $0, source: "PHB")?.id
        }
        if character.classes.isEmpty && character.preparedIDs.isEmpty && character.name == "New Caster" {
            sample.id = character.id
            character = sample
        } else {
            characters.append(sample)
            character = sample
        }
        selectedSpellID = sample.preparedIDs.last
        persistActive()
    }

    var sheetClasses: [ClassDefinition] {
        guard let library else { return [] }
        return library.classes.filter { definition in
            if definition.spellcastingAbility != nil || definition.casterProgression != nil { return true }
            return library.subclasses.contains {
                $0.className == definition.name && $0.classSource == definition.source
                    && ($0.spellcastingAbility != nil || $0.casterProgression != nil || !$0.grants.isEmpty)
            }
        }
    }

    private func publishIndex() {
        guard let library else {
            index = nil
            return
        }
        index = LibraryIndex(library: library.addingHomebrew(homebrew).addingBrews(addedBrews))
    }

    func loadBrewCatalog(force: Bool = false) {
        if brewCatalogFetched && !force { return }
        brewCatalogTask?.cancel()
        brewCatalogLoading = true
        if brewCatalog.isEmpty, let cached = loadBrewCatalogCache() {
            brewCatalog = cached
            brewCatalogMessage = "\(cached.count) homebrew documents with spells"
        } else if brewCatalog.isEmpty {
            brewCatalogMessage = "Loading the 5e.tools homebrew list"
        }
        brewCatalogTask = Task {
            do {
                let entries = try await BrewCatalog.fetchEntries()
                if Task.isCancelled { return }
                brewCatalog = entries
                brewCatalogFetched = true
                brewCatalogMessage = "\(entries.count) homebrew documents with spells"
                saveBrewCatalog(entries)
            } catch {
                if Task.isCancelled { return }
                brewCatalogMessage = brewCatalog.isEmpty
                    ? error.localizedDescription
                    : "Showing the saved list. \(error.localizedDescription)"
            }
            brewCatalogLoading = false
        }
    }

    func addBrew(_ entry: BrewCatalogEntry) {
        guard brewAddingPath == nil else { return }
        guard !addedBrews.contains(where: { $0.path == entry.path }) else { return }
        brewAddingPath = entry.path
        brewCatalogMessage = "Adding \(entry.title)"
        Task {
            do {
                let document = try await Task.detached(priority: .userInitiated) {
                    try await BrewCatalog.fetchDocument(entry)
                }.value
                addedBrews.append(document)
                addedBrews.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                saveBrews()
                publishIndex()
                brewCatalogMessage = "Added \(document.title) · \(document.spells.count) spells"
            } catch {
                brewCatalogMessage = error.localizedDescription
            }
            brewAddingPath = nil
        }
    }

    func removeBrew(_ path: String) {
        guard let document = addedBrews.first(where: { $0.path == path }) else { return }
        let removedIDs = Set(document.spells.map(\.id))
        addedBrews.removeAll { $0.path == path }
        let remaining = Set(addedBrews.flatMap { $0.spells.map(\.id) })
            .union(library?.spells.map(\.id) ?? [])
            .union(homebrew.map(\.spellID))
        let drop = removedIDs.subtracting(remaining)
        if !drop.isEmpty {
            character.preparedIDs.removeAll { drop.contains($0) }
            for index in characters.indices {
                characters[index].preparedIDs.removeAll { drop.contains($0) }
            }
            if let selectedSpellID, drop.contains(selectedSpellID) {
                self.selectedSpellID = nil
            }
            saveCharacters()
        }
        saveBrews()
        publishIndex()
        brewCatalogMessage = "Removed \(document.title)"
    }

    var filteredBrewCatalog: [BrewCatalogEntry] {
        let query = brewQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return brewCatalog }
        return brewCatalog.filter { entry in
            entry.title.localizedCaseInsensitiveContains(query)
                || entry.abbreviation.localizedCaseInsensitiveContains(query)
                || entry.path.localizedCaseInsensitiveContains(query)
                || entry.kind.localizedCaseInsensitiveContains(query)
        }
    }

    private func unusedHomebrewName(_ base: String) -> String {
        let taken = Set(homebrew.map { $0.name.lowercased() })
        if !taken.contains(base.lowercased()) { return base }
        var number = 2
        while taken.contains("\(base) \(number)".lowercased()) { number += 1 }
        return "\(base) \(number)"
    }

    private func rewritePreparedID(from old: String, to new: String?) {
        func map(_ ids: [String]) -> [String] {
            ids.compactMap { id in
                guard id == old else { return id }
                return new
            }
        }
        character.preparedIDs = map(character.preparedIDs)
        for index in characters.indices {
            characters[index].preparedIDs = map(characters[index].preparedIDs)
        }
        if selectedSpellID == old { selectedSpellID = new }
        saveCharacters()
    }

    private func unusedName(startingAt base: String) -> String {
        let taken = Set(characters.map(\.name))
        if !taken.contains(base) { return base }
        var number = 2
        while taken.contains("\(base) \(number)") {
            number += 1
        }
        return "\(base) \(number)"
    }

    private func clampExpended() {
        guard let index else { return }
        normalizeSlotStorage()
        let budget = SheetEngine.slots(index: index, character: character)
        for level in 1...9 {
            character.expendedSlots[level] = min(character.expendedSlots[level], budget.count(forSpellLevel: level))
        }
        character.expendedPact = min(character.expendedPact, budget.pactSlots)
    }

    private func normalizeSlotStorage() {
        if character.expendedSlots.count != 10 {
            character.expendedSlots = Array(repeating: 0, count: 10)
        }
    }

    private var directory: URL {
        if let override = ProcessInfo.processInfo.environment["SPELLSHEET_SUPPORT"], !override.isEmpty {
            let url = URL(fileURLWithPath: override, isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Spellsheet", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func loadColorTheme() -> AppThemeID {
        guard let raw = UserDefaults.standard.string(forKey: colorThemeKey),
              let theme = AppThemeID(rawValue: raw)
        else {
            return .parchment
        }
        return theme
    }

    private static func saveColorTheme(_ theme: AppThemeID) {
        UserDefaults.standard.set(theme.rawValue, forKey: colorThemeKey)
    }

    private func loadBrews() {
        let url = directory.appendingPathComponent("brews.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? decoder.decode([BrewDocument].self, from: data)
        else {
            addedBrews = []
            return
        }
        addedBrews = loaded
    }

    private func saveBrews() {
        let url = directory.appendingPathComponent("brews.json")
        guard let data = try? compactEncoder.encode(addedBrews) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadBrewCatalogCache() -> [BrewCatalogEntry]? {
        let url = directory.appendingPathComponent("brew-catalog.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode([BrewCatalogEntry].self, from: data)
    }

    private func saveBrewCatalog(_ entries: [BrewCatalogEntry]) {
        let url = directory.appendingPathComponent("brew-catalog.json")
        guard let data = try? compactEncoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private var compactEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func loadHomebrew() {
        let url = directory.appendingPathComponent("homebrew.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? decoder.decode([HomebrewSpell].self, from: data)
        else {
            homebrew = []
            return
        }
        homebrew = loaded
    }

    private func saveHomebrew() {
        let url = directory.appendingPathComponent("homebrew.json")
        guard let data = try? encoder.encode(homebrew) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadCharacters() {
        let url = directory.appendingPathComponent("characters.json")
        guard let data = try? Data(contentsOf: url),
              let loaded = try? decoder.decode([CharacterSheet].self, from: data),
              let first = loaded.first
        else {
            character = .makeNew()
            characters = [character]
            return
        }
        characters = loaded
        character = first
    }

    private func saveCharacters() {
        let url = directory.appendingPathComponent("characters.json")
        guard let data = try? encoder.encode(characters) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadLibrary() -> Library? {
        let url = directory.appendingPathComponent("library.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Library.self, from: data)
    }

    private func saveLibrary(_ library: Library) throws {
        let compact = JSONEncoder()
        compact.dateEncodingStrategy = .iso8601
        let url = directory.appendingPathComponent("library.json")
        let data = try compact.encode(library)
        try data.write(to: url, options: .atomic)
    }
}
