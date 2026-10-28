import AppKit
import SwiftUI
import SpellsheetCore

struct SpellColumnView: View {
    var model: AppModel

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                controls
                    .fixedSize(horizontal: false, vertical: true)
                if model.library == nil {
                    loading
                } else if model.character.classes.isEmpty {
                    emptyClasses
                } else {
                    spellList
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(Theme.ink)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("List", selection: modelBinding(model, \.listMode)) {
                ForEach(ListMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            TextField("Search spells", text: modelBinding(model, \.query))
                .textFieldStyle(.roundedBorder)
            Toggle("Show spells above your current slots", isOn: modelBinding(model, \.includeHigherLevels))
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(model.listMode == .sheet
                 ? "Spells you mark \(model.preparationWord.lowercased()) stay on this sheet."
                 : "Check \(model.preparationWord) to add a spell to the sheet. Prepared casters choose from this list.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let index = model.index {
                let profiles = SheetEngine.profiles(index: index, character: model.character)
                if profiles.count == 1, let profile = profiles.first, let limit = profile.preparationLimit {
                    let usage = SheetEngine.preparationUsage(for: profile, index: index, character: model.character)
                    let word = profile.preparationIsKnown ? "Known" : "Prepared"
                    Text("\(word) \(usage.leveled)/\(limit)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(usage.leveled > limit ? Theme.ember : Theme.gold)
                }
            }
            if let index = model.index {
                let budget = SheetEngine.slots(index: index, character: model.character)
                if budget.pactSlots > 0 {
                    HStack {
                        Text("Pact slots · \(ordinal(budget.pactLevel))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.cream)
                        Spacer()
                        SlotPips(total: budget.pactSlots, expended: model.character.expendedPact) { restore in
                            model.changePact(restore: restore)
                        }
                    }
                }
            }
        }
        .padding(14)
    }

    private var loading: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(model.loadMessage)
                .font(.callout)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyClasses: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a class to build the spell sheet.")
                .font(Theme.serif(22))
                .foregroundStyle(Theme.cream)
            Text("The class list, spell save DC, and spell attack all come from that class’s casting ability.")
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var spellList: some View {
        let rows = currentRows
        return Group {
            if rows.isEmpty {
                Text(model.listMode == .sheet
                     ? "No spells on the sheet yet. Switch to Class list and check \(model.preparationWord)."
                     : "No spells match this class, level, and search.")
                    .foregroundStyle(Theme.muted)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                MacScroll {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(grouped(rows)) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                sectionHeader(group)
                                    .padding(.horizontal, 12)
                                ForEach(group.rows) { row in
                                    SpellListRow(model: model, row: row)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(
                                            model.selectedSpellID == row.id ? Theme.card : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var currentRows: [SheetRow] {
        guard let index = model.index else { return [] }
        return SheetEngine.rows(
            index: index,
            character: model.character,
            mode: model.listMode,
            query: model.query,
            includeHigherLevels: model.includeHigherLevels
        )
    }

    private func grouped(_ rows: [SheetRow]) -> [SpellGroup] {
        let levels = Set(rows.map(\.spell.level)).sorted()
        return levels.map { level in
            SpellGroup(level: level, rows: rows.filter { $0.spell.level == level })
        }
    }

    @ViewBuilder
    private func sectionHeader(_ group: SpellGroup) -> some View {
        HStack {
            Text(group.level == 0 ? "Cantrips" : "\(ordinal(group.level))-level")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.gold)
            Spacer()
            if let index = model.index, group.level > 0 {
                let budget = SheetEngine.slots(index: index, character: model.character)
                let total = budget.count(forSpellLevel: group.level)
                if total > 0 {
                    SlotPips(total: total, expended: model.character.expendedSlots[safe: group.level] ?? 0) { restore in
                        model.changeSlot(level: group.level, restore: restore)
                    }
                }
            }
        }
    }
}

struct SpellGroup: Identifiable {
    var level: Int
    var rows: [SheetRow]
    var id: Int { level }
}

struct SpellListRow: View {
    var model: AppModel
    var row: SheetRow

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CheckButton(
                title: markTitle,
                isOn: row.onSheet,
                enabled: !row.access.alwaysPrepared
            ) {
                model.togglePrepared(row.spell.id)
            }
            .fixedSize()
            .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.spell.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.cream)
                    Spacer()
                    Text(row.spell.level == 0 ? "Cantrip" : ordinal(row.spell.level))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text("\(row.spell.castingTime) · \(row.spell.range) · \(row.spell.duration)")
                    .font(.caption)
                    .foregroundStyle(Theme.cream.opacity(0.86))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { model.selectedSpellID = row.spell.id }
        }
        .padding(.vertical, 4)
    }

    private var markTitle: String {
        if row.access.alwaysPrepared { return "Always" }
        if row.spell.level == 0 { return "Known" }
        return model.preparationWord
    }

    private var subtitle: String {
        let source: String
        if row.spell.source.caseInsensitiveCompare(HomebrewSpell.source) == .orderedSame {
            source = "Homebrew"
        } else {
            source = model.index?.library.sourceName(row.spell.source) ?? row.spell.source
        }
        var parts = [row.spell.schoolName, source, row.spell.components]
        if row.spell.concentration { parts.append("Concentration") }
        if row.spell.ritual { parts.append("Ritual") }
        if row.access.alwaysPrepared { parts.append("Always prepared") }
        if !row.access.castableNow { parts.append("Above current slots") }
        if !row.access.reasons.isEmpty { parts.append(row.access.reasons.joined(separator: ", ")) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct SlotPips: View {
    var total: Int
    var expended: Int
    var onToggle: (_ restore: Bool) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                let spent = index >= total - min(expended, total)
                Button {
                    onToggle(spent)
                } label: {
                    Circle()
                        .fill(spent ? Color.clear : Theme.gold)
                        .overlay(Circle().stroke(Theme.gold, lineWidth: 1.4))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .help(spent ? "Restore a slot" : "Expend a slot")
            }
        }
    }
}

struct SpellDetailView: View {
    var model: AppModel

    var body: some View {
        Group {
            if let spell = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(spell)
                        casting(spell)
                        facts(spell)
                        blockSection(title: nil, blocks: spell.description)
                        if !spell.higherLevel.isEmpty || !spell.scaling.isEmpty {
                            higher(spell)
                        }
                        if let url = spell.fiveEToolsURL {
                            Button("Open on 5e.tools") { NSWorkspace.shared.open(url) }
                                .buttonStyle(.bordered)
                        }
                        Text("Description and higher-level text are rendered from the 5e.tools data for \(spell.source).")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(28)
                    .frame(maxWidth: 760, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select a spell")
                        .font(Theme.serif(32))
                        .foregroundStyle(Theme.cream)
                    Text("The description, higher-level effects, spell save DC, and spell attack show up here.")
                        .foregroundStyle(Theme.muted)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(Theme.ink)
    }

    private var selected: Spell? {
        guard let id = model.selectedSpellID else { return nil }
        return model.index?.spell(id: id)
    }

    private func header(_ spell: Spell) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(spell.name)
                .font(Theme.serif(36))
                .foregroundStyle(Theme.cream)
            Text("\(spell.levelName) · \(spell.schoolName)")
                .font(.title3)
                .foregroundStyle(Theme.gold)
            Text(sourceLine(spell))
                .font(.callout)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 6) {
                badge(spell.components)
                if spell.concentration { badge("Concentration") }
                if spell.ritual { badge("Ritual") }
                if !spell.savingThrows.isEmpty { badge(spell.savingThrows.joined(separator: ", ") + " save") }
                if !spell.attackKinds.isEmpty { badge(attackLabel(spell.attackKinds)) }
            }
        }
    }

    private func casting(_ spell: Spell) -> some View {
        let profiles = model.index.map { SheetEngine.profiles(index: $0, character: model.character) } ?? []
        let access = model.index.flatMap { SheetEngine.accessMap(index: $0, character: model.character)[spell.id] }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Your spellcasting")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.gold)
            if profiles.isEmpty {
                Text("Add a spellcasting class to calculate the save DC and spell attack.")
                    .foregroundStyle(Theme.muted)
            }
            ForEach(profiles) { profile in
                let relevant = grants(profile, access: access)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.title)
                        .font(.headline)
                        .foregroundStyle(relevant ? Theme.cream : Theme.muted)
                    if profile.ability == nil {
                        Text("Choose a spellcasting ability for this class.")
                            .foregroundStyle(Theme.muted)
                    } else {
                        HStack(spacing: 18) {
                            labeled("Spell save DC", "\(profile.saveDC)")
                            labeled("Spell attack", CastingMath.signed(profile.attackBonus))
                        }
                        Text("\(profile.ability?.name ?? "") \(CastingMath.signed(profile.modifier)), proficiency \(CastingMath.signed(profile.proficiency)).")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        if !spell.savingThrows.isEmpty {
                            Text("\(spell.savingThrows.joined(separator: " or ")) save: DC \(profile.saveDC).")
                                .foregroundStyle(Theme.cream)
                        }
                        if !spell.attackKinds.isEmpty {
                            Text("\(attackLabel(spell.attackKinds)): \(CastingMath.signed(profile.attackBonus)).")
                                .foregroundStyle(Theme.cream)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(relevant ? Theme.card : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func facts(_ spell: Spell) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fact("Casting time", spell.castingTime)
            fact("Range", spell.range)
            fact("Duration", spell.duration)
            fact("Components", componentLine(spell))
            if !spell.damage.isEmpty { fact("Damage", spell.damage.joined(separator: ", ")) }
        }
        .card()
    }

    private func higher(_ spell: Spell) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Higher levels")
                .font(Theme.serif(22))
                .foregroundStyle(Theme.gold)
            if !spell.scaling.isEmpty {
                let level = max(model.character.totalLevel, 1)
                Text("At character level \(level), the cantrip uses \(spell.dice(atCharacterLevel: level) ?? "its base dice").")
                    .foregroundStyle(Theme.cream)
                Text(spell.scaling.map { "\(ordinal($0.level)) \($0.dice)" }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            blockSection(title: nil, blocks: spell.higherLevel)
        }
        .card()
    }

    @ViewBuilder
    private func blockSection(title: String?, blocks: [SpellBlock]) -> some View {
        if let title {
            Text(title).font(Theme.serif(22)).foregroundStyle(Theme.gold)
        }
        ForEach(blocks) { block in
            switch block.kind {
            case .heading:
                Text(block.text)
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 4)
            case .paragraph:
                Text(block.text)
                    .foregroundStyle(Theme.cream)
                    .fixedSize(horizontal: false, vertical: true)
            case .bullet:
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundStyle(Theme.gold)
                    Text(block.text)
                        .foregroundStyle(Theme.cream)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .table:
                VStack(alignment: .leading, spacing: 6) {
                    if !block.text.isEmpty {
                        Text(block.text).font(.headline).foregroundStyle(Theme.cream)
                    }
                    ScrollView(.horizontal) {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                            GridRow {
                                ForEach(Array(block.columns.enumerated()), id: \.offset) { _, column in
                                    Text(column).font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                                }
                            }
                            ForEach(Array(block.rows.enumerated()), id: \.offset) { _, row in
                                GridRow {
                                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                        Text(cell).font(.caption).foregroundStyle(Theme.cream)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 110, alignment: .leading)
                .foregroundStyle(Theme.muted)
            Text(value)
                .foregroundStyle(Theme.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(Theme.serif(26))
                .foregroundStyle(Theme.gold)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.cream)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.card, in: Capsule())
    }

    private func sourceLine(_ spell: Spell) -> String {
        if spell.source.caseInsensitiveCompare(HomebrewSpell.source) == .orderedSame { return "Homebrew" }
        let book = model.index?.library.sourceName(spell.source) ?? spell.source
        if let page = spell.page { return "\(book) (\(spell.source)), page \(page)" }
        return "\(book) (\(spell.source))"
    }

    private func componentLine(_ spell: Spell) -> String {
        if let material = spell.material, !material.isEmpty {
            return "\(spell.components) (\(material))"
        }
        return spell.components
    }

    private func attackLabel(_ kinds: [String]) -> String {
        let names = kinds.map { kind -> String in
            switch kind.uppercased() {
            case "R": "Ranged spell attack"
            case "M": "Melee spell attack"
            default: "Spell attack"
            }
        }
        return names.joined(separator: ", ")
    }

    private func grants(_ profile: CastingProfile, access: SpellAccess?) -> Bool {
        guard let access else { return false }
        if access.reasons.contains(profile.className) { return true }
        if let subclass = profile.subclassName, access.reasons.contains(subclass) { return true }
        return false
    }
}

struct BrewChooser: View {
    var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a homebrew document from the 5e.tools collection. Its spells join the class lists named in that file.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                TextField("Search homebrew", text: modelBinding(model, \.brewQuery))
                    .textFieldStyle(.roundedBorder)
                Button(model.brewCatalogLoading ? "Loading…" : "Reload") {
                    model.loadBrewCatalog(force: true)
                }
                .disabled(model.brewCatalogLoading)
            }
            Text(model.brewCatalogMessage)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
            if model.brewCatalog.isEmpty {
                VStack(spacing: 8) {
                    if model.brewCatalogLoading { ProgressView() }
                    Text(model.brewCatalogLoading ? "Fetching the homebrew list." : "The homebrew list is not available yet.")
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.filteredBrewCatalog) { entry in
                    brewRow(entry)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func brewRow(_ entry: BrewCatalogEntry) -> some View {
        let added = model.addedBrews.first { $0.path == entry.path }
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                Text(detail(entry, added: added))
                    .font(.caption)
                    .foregroundStyle(entry.status == "deprecated" ? Theme.ember : Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if model.brewAddingPath == entry.path {
                ProgressView().controlSize(.small)
            } else if added != nil {
                Button("Remove") { model.removeBrew(entry.path) }
                    .buttonStyle(.bordered)
            } else {
                Button("Add") { model.addBrew(entry) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.brewAddingPath != nil)
            }
        }
        .padding(.vertical, 2)
    }

    private func detail(_ entry: BrewCatalogEntry, added: BrewDocument?) -> String {
        var parts: [String] = []
        if !entry.abbreviation.isEmpty { parts.append(entry.abbreviation) }
        parts.append(entry.edition)
        parts.append(entry.kind)
        if !entry.status.isEmpty { parts.append(entry.status) }
        if let added { parts.append("\(added.spells.count) spells added") }
        return parts.joined(separator: " · ")
    }
}

struct AddClassSheet: View {
    var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add a class")
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Button("Close") { model.showingAddClass = false }
            }
            Text("Spell lists follow the class and source you pick. A 2014 wizard and a 2024 wizard do not share a list.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            TextField("Search classes", text: modelBinding(model, \.classSearch))
                .textFieldStyle(.roundedBorder)
            Picker("Edition", selection: modelBinding(model, \.classEdition)) {
                Text("All").tag("All")
                Text("2014").tag("2014")
                Text("2024").tag("2024")
            }
            .pickerStyle(.segmented)
            List(filtered) { definition in
                Button {
                    model.addClass(definition)
                    model.showingAddClass = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(definition.name)
                                .foregroundStyle(Theme.cream)
                            Text("\(definition.editionLabel) · \(model.library?.sourceName(definition.source) ?? definition.source)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if already(definition) {
                            Text("Added").foregroundStyle(Theme.muted)
                        } else if let ability = definition.spellcastingAbility {
                            Text(ability.name).foregroundStyle(Theme.gold)
                        } else {
                            Text("Subclass caster").foregroundStyle(Theme.muted)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(already(definition))
            }
            .scrollContentBackground(.hidden)
        }
        .padding(16)
        .frame(width: 480, height: 580)
        .background(Theme.panel)
    }

    private var filtered: [ClassDefinition] {
        model.sheetClasses.filter { definition in
            (model.classEdition == "All" || definition.editionLabel == model.classEdition)
                && (model.classSearch.isEmpty
                    || definition.name.localizedCaseInsensitiveContains(model.classSearch)
                    || definition.source.localizedCaseInsensitiveContains(model.classSearch))
        }
    }

    private func already(_ definition: ClassDefinition) -> Bool {
        model.character.classes.contains { $0.className == definition.name && $0.classSource == definition.source }
    }
}

struct SettingsSheet: View {
    var model: AppModel

    private let schools = ["A", "C", "D", "E", "I", "N", "P", "T", "V"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Settings")
                    .font(Theme.serif(26))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Picker("Section", selection: modelBinding(model, \.settingsTab)) {
                    Text("5e.tools homebrew").tag(SettingsTab.repository)
                    Text("My spells").tag(SettingsTab.spells)
                }
                .pickerStyle(.segmented)
                .frame(width: 340)
                Button("Close") { model.showingSettings = false }
            }
            .padding(16)
            Divider().overlay(Theme.line)
            switch model.settingsTab {
            case .repository:
                BrewChooser(model: model)
            case .spells:
                HStack(alignment: .top, spacing: 0) {
                    spellList
                        .frame(width: 230)
                    Divider().overlay(Theme.line)
                    editor
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 880, height: 680)
        .background(Theme.panel)
        .onAppear {
            model.loadBrewCatalog()
            if model.homebrewDraft == nil {
                model.homebrewDraft = model.homebrew.first
            }
        }
    }

    private var spellList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Homebrew")
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Button("Add") { model.addHomebrew() }
                    .buttonStyle(.bordered)
            }
            Text("Spells you add here show up on the class lists you check.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if model.homebrew.isEmpty {
                Text("No homebrew spells yet.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
            } else {
                List(selection: Binding(
                    get: { model.homebrewDraft?.id },
                    set: { model.selectHomebrew($0) }
                )) {
                    ForEach(model.homebrew) { spell in
                        Text(spellLabel(spell))
                            .tag(Optional(spell.id))
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var editor: some View {
        Group {
            if let draft = model.homebrewDraft {
                editorForm(draft)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a homebrew spell")
                        .font(Theme.serif(26))
                        .foregroundStyle(Theme.cream)
                    Text("It can be marked \(model.preparationWord.lowercased()) from the class list, the same way as a book spell.")
                        .foregroundStyle(Theme.muted)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func editorForm(_ draft: HomebrewSpell) -> some View {
        MacScroll {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Edit spell")
                        .font(Theme.serif(26))
                        .foregroundStyle(Theme.cream)
                    Spacer()
                    Button("Delete Spell", role: .destructive) { model.deleteHomebrew(draft.id) }
                        .buttonStyle(.bordered)
                }
                labeled("Name") {
                    CommitField(text: draft.name) { name in
                        model.editHomebrewDraft { $0.name = name }
                        model.commitHomebrewDraft()
                    }
                    .frame(height: 24)
                }
                HStack(alignment: .center, spacing: 16) {
                    Stepper(value: Binding(
                        get: { draft.level },
                        set: { level in
                            model.editHomebrewDraft { $0.level = level }
                            model.commitHomebrewDraft()
                        }
                    ), in: 0...9) {
                        Text(draft.level == 0 ? "Cantrip" : "\(ordinal(draft.level)) level")
                            .foregroundStyle(Theme.cream)
                    }
                    .frame(width: 180)
                    Picker("School", selection: Binding(
                        get: { draft.school },
                        set: { school in
                            model.editHomebrewDraft { $0.school = school }
                            model.commitHomebrewDraft()
                        }
                    )) {
                        ForEach(schools, id: \.self) { code in
                            Text(Spell.schoolName(code)).tag(code)
                        }
                    }
                    .frame(maxWidth: 240)
                }
                HStack(spacing: 8) {
                    shortField("Casting time", draft.castingTime) { value in
                        model.editHomebrewDraft { $0.castingTime = value }
                    }
                    shortField("Range", draft.range) { value in
                        model.editHomebrewDraft { $0.range = value }
                    }
                    shortField("Duration", draft.duration) { value in
                        model.editHomebrewDraft { $0.duration = value }
                    }
                }
                labeled("Components") {
                    CommitField(text: draft.components) { value in
                        model.editHomebrewDraft { $0.components = value }
                        model.commitHomebrewDraft()
                    }
                    .frame(height: 24)
                }
                HStack(spacing: 16) {
                    CheckButton(title: "Concentration", isOn: draft.concentration) {
                        model.editHomebrewDraft { $0.concentration.toggle() }
                        model.commitHomebrewDraft()
                    }
                    .fixedSize()
                    CheckButton(title: "Ritual", isOn: draft.ritual) {
                        model.editHomebrewDraft { $0.ritual.toggle() }
                        model.commitHomebrewDraft()
                    }
                    .fixedSize()
                }
                labeled("Description") {
                    CommitField(text: draft.summary, multiline: true) { value in
                        model.editHomebrewDraft { $0.summary = value }
                        model.commitHomebrewDraft()
                    }
                    .frame(height: 72)
                }
                labeled("At higher levels") {
                    CommitField(text: draft.higherLevel, multiline: true) { value in
                        model.editHomebrewDraft { $0.higherLevel = value }
                        model.commitHomebrewDraft()
                    }
                    .frame(height: 56)
                }
                Text("Class lists")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                Text("Checked classes see this spell on their class list.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                TextField("Search classes", text: modelBinding(model, \.settingsClassQuery))
                    .textFieldStyle(.roundedBorder)
                ForEach(filteredClasses) { definition in
                    CheckButton(
                        title: "\(definition.name) · \(definition.editionLabel) · \(definition.source)",
                        isOn: draft.classes.contains { $0.name == definition.name && $0.source == definition.source }
                    ) {
                        let ref = ClassRef(name: definition.name, source: definition.source)
                        let included = draft.classes.contains { $0.name == ref.name && $0.source == ref.source }
                        model.editHomebrewDraft { spell in
                            if included {
                                spell.classes.removeAll { $0.name == ref.name && $0.source == ref.source }
                            } else {
                                spell.classes.append(ref)
                            }
                        }
                        model.commitHomebrewDraft()
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var filteredClasses: [ClassDefinition] {
        model.sheetClasses.filter { definition in
            model.settingsClassQuery.isEmpty
                || definition.name.localizedCaseInsensitiveContains(model.settingsClassQuery)
                || definition.source.localizedCaseInsensitiveContains(model.settingsClassQuery)
        }
    }

    private func spellLabel(_ spell: HomebrewSpell) -> String {
        let level = spell.level == 0 ? "Cantrip" : ordinal(spell.level)
        return "\(spell.name) · \(level)"
    }

    private func shortField(_ title: String, _ text: String, _ set: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            CommitField(text: text) { value in
                set(value)
                model.commitHomebrewDraft()
            }
            .frame(height: 24)
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            content()
        }
    }
}

private struct CommitField: NSViewRepresentable {
    var text: String
    var multiline = false
    var onCommit: (String) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: 13)
        field.delegate = context.coordinator
        field.stringValue = text
        field.usesSingleLineMode = !multiline
        field.cell?.wraps = multiline
        field.cell?.isScrollable = false
        if multiline { field.maximumNumberOfLines = 6 }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.onCommit = onCommit
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCommit: onCommit)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var onCommit: (String) -> Void
        init(onCommit: @escaping (String) -> Void) { self.onCommit = onCommit }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            onCommit(field.stringValue)
        }
    }
}

private extension Array where Element == Int {
    subscript(safe index: Int) -> Int? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
