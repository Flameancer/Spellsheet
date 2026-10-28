import AppKit
import SwiftUI
import SpellsheetCore

private struct PresentationAnchor: View {
    var model: AppModel

    var body: some View {
        Color.clear
            .sheet(isPresented: modelBinding(model, \.showingAddClass)) {
                AddClassSheet(model: model)
            }
            .confirmationDialog(
                "Delete \(model.character.name)?",
                isPresented: modelBinding(model, \.confirmingDelete),
                titleVisibility: .visible
            ) {
                Button("Delete Character", role: .destructive) { model.deleteActive() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the character from this Mac.")
            }
            .sheet(isPresented: modelBinding(model, \.showingSettings), onDismiss: { model.commitHomebrewDraft() }) {
                SettingsSheet(model: model)
            }
    }
}

struct RootView: View {
    var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } content: {
            SpellColumnView(model: model)
                .navigationSplitViewColumnWidth(min: 320, ideal: 390, max: 520)
        } detail: {
            SpellDetailView(model: model)
                .navigationSplitViewColumnWidth(min: 340, ideal: 460, max: 900)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Theme.ink)
        .toolbar { toolbar }
        .onAppear {
            model.bootstrap()
            fitWindowToScreen()
        }
        .onChange(of: model.character) { model.persistActive() }
        .onChange(of: model.listMode) { fitWindowToScreen() }
        .background { PresentationAnchor(model: model) }
    }

    /// A spell list used to report its full height and push the window off the screen.
    private func fitWindowToScreen() {
        DispatchQueue.main.async {
            let window = NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible }
            guard let window, let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
            var frame = window.frame
            let tooTall = frame.height > visible.height + 8
            let tooWide = frame.width > visible.width + 8
            let offscreen = frame.maxY > visible.maxY + 8 || frame.minY < visible.minY - 8
                || frame.minX < visible.minX - 8 || frame.maxX > visible.maxX + 8
            guard tooTall || tooWide || offscreen else { return }
            if tooTall { frame.size.height = visible.height }
            if tooWide { frame.size.width = min(frame.width, visible.width) }
            if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - frame.height }
            if frame.minY < visible.minY { frame.origin.y = visible.minY }
            if frame.minX < visible.minX { frame.origin.x = visible.minX }
            if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
            window.setFrame(frame, display: true)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button("Long Rest") { model.longRest() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Settings") { model.showingSettings = true }
            Button(model.isLoading ? "Refreshing…" : "Refresh 5e.tools") { model.refresh() }
                .disabled(model.isLoading)
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

struct SidebarView: View {
    var model: AppModel

    var body: some View {
        GeometryReader { geo in
            sidebarContent
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(Theme.panel)
        .navigationTitle("Spellsheet")
    }

    private var sidebarContent: some View {
        MacScroll {
            VStack(alignment: .leading, spacing: 16) {
                characterPicker
                abilityGrid
                if let index = model.index {
                    let profiles = SheetEngine.profiles(index: index, character: model.character)
                    let budget = SheetEngine.slots(index: index, character: model.character)
                    ForEach(model.character.classes) { pick in
                        ClassCard(
                            model: model,
                            pick: pick,
                            profile: profiles.first { $0.id == pick.id },
                            usage: profiles.first { $0.id == pick.id }.map {
                                SheetEngine.preparationUsage(for: $0, index: index, character: model.character)
                            }
                        )
                    }
                    if !budget.contributions.isEmpty {
                        Text(budget.contributions.joined(separator: ". ") + ". Caster level \(budget.casterLevel).")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button {
                    model.showingAddClass = true
                } label: {
                    Label("Add Class", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.library == nil)
                if model.character.classes.isEmpty {
                    Button("Use a sample 5th-level wizard") { model.useSampleWizard() }
                        .buttonStyle(.bordered)
                        .disabled(model.library == nil)
                }
                dataStatus
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var characterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Character name", text: modelBinding(model, \.character.name))
                .textFieldStyle(.plain)
                .font(Theme.serif(26))
                .foregroundStyle(Theme.cream)
            HStack(spacing: 8) {
                CharacterPopup(
                    characters: model.characters,
                    selected: model.character.id,
                    onSelect: { model.showCharacter($0) }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                ActionButton(systemImage: "plus", help: "New character") { model.newCharacter() }
                    .frame(width: 36, height: 28)
                ActionButton(systemImage: "trash", help: "Delete character") { model.confirmingDelete = true }
                    .frame(width: 36, height: 28)
            }
            let level = max(model.character.totalLevel, 1)
            Text("Level \(model.character.totalLevel) · Proficiency \(CastingMath.signed(CastingMath.proficiency(totalLevel: level)))")
                .font(.callout)
                .foregroundStyle(Theme.gold)
            Text("Spell save DC is 8 + proficiency + casting ability. Spell attack is proficiency + that same modifier.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var abilityGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                scoreDial(.strength)
                scoreDial(.dexterity)
                scoreDial(.constitution)
            }
            GridRow {
                scoreDial(.intelligence)
                scoreDial(.wisdom)
                scoreDial(.charisma)
            }
        }
    }

    private func scoreDial(_ ability: Ability) -> some View {
        ScoreDial(
            title: ability.shortName,
            score: model.character.scores.score(ability)
        ) { model.setScore(ability, $0) }
    }

    private var dataStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.ember)
            }
            Text(model.loadMessage)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Text("Spell text is loaded from the 5e.tools dataset and linked back to 5e.tools. It remains Wizards of the Coast’s material.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ScoreField: NSViewRepresentable {
    var title: String
    var score: Int
    var onCommit: (Int) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.alignment = .center
        field.font = .systemFont(ofSize: 18, weight: .semibold)
        field.textColor = Theme.active.creamNSColor
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.stringValue = "\(score)"
        field.setAccessibilityLabel(title)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.onCommit = onCommit
        context.coordinator.score = score
        _ = AppStore.shared.colorTheme
        field.textColor = Theme.active.creamNSColor
        let editing = field.currentEditor() != nil
        if !editing, field.stringValue != "\(score)" {
            field.stringValue = "\(score)"
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(score: score, onCommit: onCommit)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var score: Int
        var onCommit: (Int) -> Void
        init(score: Int, onCommit: @escaping (Int) -> Void) {
            self.score = score
            self.onCommit = onCommit
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let parsed = Int(field.stringValue.trimmingCharacters(in: .whitespaces))
            let clamped = min(30, max(1, parsed ?? score))
            field.stringValue = "\(clamped)"
            if clamped != score {
                onCommit(clamped)
            }
        }
    }
}

struct ScoreDial: View {
    var title: String
    var score: Int
    var onChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            ScoreField(title: title, score: score, onCommit: onChange)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .padding(.vertical, 2)
                .background(Theme.ink.opacity(0.55), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityLabel(title)
            Text(CastingMath.signed(CastingMath.abilityModifier(score)))
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.gold)
            HStack(spacing: 6) {
                ActionButton(systemImage: "minus", help: "Decrease \(title)", compact: true) {
                    onChange(score - 1)
                }
                .frame(width: 28, height: 22)
                ActionButton(systemImage: "plus", help: "Increase \(title)", compact: true) {
                    onChange(score + 1)
                }
                .frame(width: 28, height: 22)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ClassCard: View {
    var model: AppModel
    var pick: ClassPick
    var profile: CastingProfile?
    var usage: (cantrips: Int, leveled: Int)?

    private var definition: ClassDefinition? {
        model.index?.library.classes.first { $0.name == pick.className && $0.source == pick.classSource }
    }

    private var subclassOptions: [SubclassDefinition] {
        guard let definition, let library = model.library else { return [] }
        return SheetEngine.subclasses(for: definition, in: library)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pick.className)
                        .font(Theme.serif(18))
                        .foregroundStyle(Theme.cream)
                    Text("\(definition?.editionLabel ?? "") · \(pick.classSource)")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Stepper(value: Binding(
                    get: { pick.level },
                    set: { model.setLevel(pick.id, $0) }
                ), in: 1...20) {
                    Text("Level \(pick.level)")
                        .foregroundStyle(Theme.cream)
                }
                .frame(width: 130)
                ActionButton(systemImage: "xmark", help: "Remove \(pick.className)", compact: true) {
                    model.removeClass(pick.id)
                }
                .frame(width: 28, height: 22)
            }
            if !subclassOptions.isEmpty {
                Picker("Subclass", selection: Binding(
                    get: { subclassKey },
                    set: { key in
                        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
                        if parts.count == 2 {
                            model.setSubclass(pick.id, name: parts[0], source: parts[1])
                        } else {
                            model.setSubclass(pick.id, name: nil, source: nil)
                        }
                    }
                )) {
                    Text("No subclass").tag("")
                    ForEach(subclassOptions) { option in
                        Text("\(option.name) (\(option.source))").tag("\(option.name)|\(option.source)")
                    }
                }
            }
            if let profile, !profileFocuses(profile).isEmpty {
                Picker("Focus", selection: Binding(
                    get: { pick.focus ?? "" },
                    set: { model.setFocus(pick.id, $0.isEmpty ? nil : $0) }
                )) {
                    Text("Choose").tag("")
                    ForEach(profileFocuses(profile), id: \.self) { focus in
                        Text(focus).tag(focus)
                    }
                }
            }
            Picker("Casting ability", selection: Binding(
                get: { pick.abilityOverride ?? profile?.ability },
                set: { model.setAbility(pick.id, $0) }
            )) {
                Text("Choose").tag(Optional<Ability>.none)
                ForEach(Ability.allCases) { ability in
                    Text(ability.name).tag(Optional(ability))
                }
            }
            if let profile, profile.ability != nil {
                HStack(spacing: 16) {
                    statBlock(title: "Spell save DC", value: "\(profile.saveDC)")
                    statBlock(title: "Spell attack", value: CastingMath.signed(profile.attackBonus))
                }
                Text("\(profile.ability?.name ?? "") \(CastingMath.signed(profile.modifier)) · proficiency \(CastingMath.signed(profile.proficiency))")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                preparationLine(profile)
            } else {
                Text("Choose the ability this class casts with. Fighter and rogue spells come from a subclass such as Eldritch Knight or Arcane Trickster.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private var subclassKey: String {
        guard let name = pick.subclassName, let source = pick.subclassSource else { return "" }
        return "\(name)|\(source)"
    }

    private func profileFocuses(_ profile: CastingProfile) -> [String] {
        guard let name = profile.subclassName else { return [] }
        return model.library?.subclasses.first {
            $0.name == name && $0.className == profile.className && $0.classSource == profile.classSource
        }?.focuses ?? []
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(Theme.serif(28))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    private func preparationLine(_ profile: CastingProfile) -> some View {
        let used = usage ?? (0, 0)
        VStack(alignment: .leading, spacing: 2) {
            if let limit = profile.cantripLimit {
                Text("Cantrips \(used.cantrips)/\(limit)")
                    .foregroundStyle(used.cantrips > limit ? Theme.ember : Theme.cream)
            }
            if let limit = profile.preparationLimit {
                let label = profile.preparationIsKnown ? "Spells known" : "Prepared"
                Text("\(label) \(used.leveled)/\(limit)")
                    .foregroundStyle(used.leveled > limit ? Theme.ember : Theme.cream)
            }
            if profile.maxSpellLevel > 0 {
                Text("Spells up to \(ordinal(profile.maxSpellLevel)) level")
                    .foregroundStyle(Theme.muted)
            }
        }
        .font(.callout)
    }
}
