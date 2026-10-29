import AppKit
import SpellsheetCore
import SwiftUI

func modelBinding<T>(_ model: AppModel, _ keyPath: ReferenceWritableKeyPath<AppModel, T>) -> Binding<T> {
    Binding(
        get: { model[keyPath: keyPath] },
        set: { model[keyPath: keyPath] = $0 }
    )
}

struct ColorPalette: Equatable {
    var ink: Color
    var panel: Color
    var card: Color
    var line: Color
    var cream: Color
    var muted: Color
    var gold: Color
    var ember: Color
    var moss: Color
    var prefersDark: Bool

    var creamNSColor: NSColor {
        NSColor(cream)
    }
}

enum AppThemeID: String, CaseIterable, Identifiable, Codable {
    case parchment
    case midnight
    case grove
    case emberhall
    case storm
    case ivory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parchment: "Parchment"
        case .midnight: "Midnight"
        case .grove: "Grove"
        case .emberhall: "Emberhall"
        case .storm: "Storm"
        case .ivory: "Ivory"
        }
    }

    var blurb: String {
        switch self {
        case .parchment: "Warm candlelit browns and gold"
        case .midnight: "Deep night blues and silver"
        case .grove: "Forest greens and soft gold"
        case .emberhall: "Charcoal halls and hot coals"
        case .storm: "Cool slate with lightning cyan"
        case .ivory: "Light parchment desk"
        }
    }

    var palette: ColorPalette {
        switch self {
        case .parchment:
            ColorPalette(
                ink: Color(red: 0.09, green: 0.07, blue: 0.06),
                panel: Color(red: 0.14, green: 0.11, blue: 0.09),
                card: Color(red: 0.20, green: 0.15, blue: 0.12),
                line: Color(red: 0.39, green: 0.30, blue: 0.22),
                cream: Color(red: 0.96, green: 0.91, blue: 0.82),
                muted: Color(red: 0.72, green: 0.63, blue: 0.51),
                gold: Color(red: 0.82, green: 0.64, blue: 0.35),
                ember: Color(red: 0.76, green: 0.36, blue: 0.26),
                moss: Color(red: 0.49, green: 0.66, blue: 0.45),
                prefersDark: true
            )
        case .midnight:
            ColorPalette(
                ink: Color(red: 0.05, green: 0.07, blue: 0.12),
                panel: Color(red: 0.09, green: 0.12, blue: 0.20),
                card: Color(red: 0.13, green: 0.17, blue: 0.28),
                line: Color(red: 0.28, green: 0.36, blue: 0.52),
                cream: Color(red: 0.88, green: 0.91, blue: 0.97),
                muted: Color(red: 0.58, green: 0.65, blue: 0.78),
                gold: Color(red: 0.72, green: 0.80, blue: 0.94),
                ember: Color(red: 0.86, green: 0.42, blue: 0.48),
                moss: Color(red: 0.42, green: 0.72, blue: 0.68),
                prefersDark: true
            )
        case .grove:
            ColorPalette(
                ink: Color(red: 0.06, green: 0.09, blue: 0.06),
                panel: Color(red: 0.10, green: 0.15, blue: 0.10),
                card: Color(red: 0.15, green: 0.22, blue: 0.15),
                line: Color(red: 0.30, green: 0.42, blue: 0.30),
                cream: Color(red: 0.90, green: 0.93, blue: 0.84),
                muted: Color(red: 0.62, green: 0.72, blue: 0.58),
                gold: Color(red: 0.82, green: 0.70, blue: 0.38),
                ember: Color(red: 0.78, green: 0.42, blue: 0.28),
                moss: Color(red: 0.48, green: 0.72, blue: 0.46),
                prefersDark: true
            )
        case .emberhall:
            ColorPalette(
                ink: Color(red: 0.07, green: 0.06, blue: 0.06),
                panel: Color(red: 0.12, green: 0.10, blue: 0.09),
                card: Color(red: 0.18, green: 0.14, blue: 0.12),
                line: Color(red: 0.42, green: 0.28, blue: 0.22),
                cream: Color(red: 0.94, green: 0.88, blue: 0.82),
                muted: Color(red: 0.70, green: 0.58, blue: 0.52),
                gold: Color(red: 0.92, green: 0.58, blue: 0.28),
                ember: Color(red: 0.88, green: 0.32, blue: 0.22),
                moss: Color(red: 0.55, green: 0.62, blue: 0.40),
                prefersDark: true
            )
        case .storm:
            ColorPalette(
                ink: Color(red: 0.07, green: 0.08, blue: 0.10),
                panel: Color(red: 0.11, green: 0.13, blue: 0.16),
                card: Color(red: 0.16, green: 0.19, blue: 0.23),
                line: Color(red: 0.34, green: 0.40, blue: 0.46),
                cream: Color(red: 0.90, green: 0.93, blue: 0.95),
                muted: Color(red: 0.62, green: 0.68, blue: 0.74),
                gold: Color(red: 0.45, green: 0.78, blue: 0.86),
                ember: Color(red: 0.86, green: 0.46, blue: 0.38),
                moss: Color(red: 0.46, green: 0.70, blue: 0.62),
                prefersDark: true
            )
        case .ivory:
            ColorPalette(
                ink: Color(red: 0.94, green: 0.91, blue: 0.84),
                panel: Color(red: 0.90, green: 0.86, blue: 0.78),
                card: Color(red: 0.98, green: 0.96, blue: 0.91),
                line: Color(red: 0.72, green: 0.64, blue: 0.50),
                cream: Color(red: 0.18, green: 0.14, blue: 0.10),
                muted: Color(red: 0.42, green: 0.36, blue: 0.28),
                gold: Color(red: 0.58, green: 0.42, blue: 0.18),
                ember: Color(red: 0.72, green: 0.28, blue: 0.18),
                moss: Color(red: 0.32, green: 0.48, blue: 0.30),
                prefersDark: false
            )
        }
    }
}

/// Reads the active palette from `AppStore` so SwiftUI views re-render on change.
@MainActor
enum Theme {
    static var active: ColorPalette { AppStore.shared.colorTheme.palette }

    static var ink: Color { active.ink }
    static var panel: Color { active.panel }
    static var card: Color { active.card }
    static var line: Color { active.line }
    static var cream: Color { active.cream }
    static var muted: Color { active.muted }
    static var gold: Color { active.gold }
    static var ember: Color { active.ember }
    static var moss: Color { active.moss }

    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.line.opacity(0.7), lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// SwiftUI's scroll view cancels the click before an AppKit button can track it.
/// This button claims the mouse itself and fires on mouse-up inside its bounds.
class ClickButton: NSButton {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, bounds.contains(point) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let window else { return }
        isHighlighted = true
        let mask: NSEvent.EventTypeMask = [.leftMouseUp, .leftMouseDragged]
        while let next = window.nextEvent(matching: mask) {
            let inside = bounds.contains(convert(next.locationInWindow, from: nil))
            isHighlighted = inside
            if next.type == .leftMouseUp {
                isHighlighted = false
                if inside {
                    _ = sendAction(action, to: target)
                }
                break
            }
        }
    }
}

final class ClickPopup: NSPopUpButton {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, bounds.contains(point) else { return nil }
        return self
    }
}

/// SwiftUI `Button`s inside the sidebar scroll view do not receive clicks.
/// An AppKit button does.
struct ActionButton: NSViewRepresentable {
    var systemImage: String
    var help: String
    var compact = false
    var action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = IconNSButton()
        button.preferred = NSSize(width: compact ? 28 : 34, height: compact ? 22 : 26)
        button.bezelStyle = .rounded
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.controlSize = compact ? .mini : .small
        button.target = context.coordinator
        button.action = #selector(Coordinator.press)
        apply(button)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        apply(button)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    private func apply(_ button: NSButton) {
        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: help)
        button.toolTip = help
        button.setAccessibilityLabel(help)
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @MainActor @objc func press() { action() }
    }
}

/// Keeps the bezel inside the slot SwiftUI assigned. The default image button
/// reports a larger size and overlaps its neighbor.
private final class IconNSButton: ClickButton {
    var preferred = NSSize(width: 28, height: 22)
    override var intrinsicContentSize: NSSize { preferred }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }
}

struct CheckButton: NSViewRepresentable {
    var title: String
    var isOn: Bool
    var enabled: Bool = true
    var action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = ClickButton()
        button.setButtonType(.switch)
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.target = context.coordinator
        button.action = #selector(Coordinator.press)
        apply(button, context: context)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        apply(button, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    private func apply(_ button: NSButton, context: Context) {
        _ = AppStore.shared.colorTheme
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: Theme.active.creamNSColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            ]
        )
        button.state = isOn ? .on : .off
        button.isEnabled = enabled
        button.setAccessibilityLabel(title)
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @MainActor @objc func press() { action() }
    }
}

struct CharacterPopup: NSViewRepresentable {
    var characters: [CharacterSheet]
    var selected: UUID
    var onSelect: (UUID) -> Void

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = ClickPopup()
        popup.bezelStyle = .rounded
        popup.controlSize = .regular
        popup.target = context.coordinator
        popup.action = #selector(Coordinator.pick(_:))
        popup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        context.coordinator.onSelect = onSelect
        let titles = characters.map(Self.title)
        let changed = popup.numberOfItems != titles.count
            || (0..<popup.numberOfItems).contains { popup.item(at: $0)?.title != titles[$0] }
        if changed {
            popup.removeAllItems()
            for (index, character) in characters.enumerated() {
                popup.addItem(withTitle: titles[index])
                popup.lastItem?.representedObject = character.id
            }
        }
        if let index = characters.firstIndex(where: { $0.id == selected }),
           popup.indexOfSelectedItem != index {
            popup.selectItem(at: index)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    private static func title(_ saved: CharacterSheet) -> String {
        let name = saved.name.isEmpty ? "Unnamed" : saved.name
        let classes = saved.classes.map(\.className).joined(separator: ", ")
        return classes.isEmpty ? name : "\(name) · \(classes)"
    }

    final class Coordinator: NSObject {
        var onSelect: (UUID) -> Void
        init(onSelect: @escaping (UUID) -> Void) { self.onSelect = onSelect }
        @MainActor @objc func pick(_ sender: NSPopUpButton) {
            guard let id = sender.selectedItem?.representedObject as? UUID else { return }
            onSelect(id)
        }
    }
}

struct MacScroll<Content: View>: NSViewRepresentable {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> FittingScrollView {
        let scroll = FittingScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder
        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = true
        scroll.documentView = host
        context.coordinator.host = host
        scroll.measureHeight = { [weak host] width in
            guard let host else { return 1 }
            host.setFrameSize(NSSize(width: width, height: max(host.frame.height, 1)))
            host.layoutSubtreeIfNeeded()
            return max(host.fittingSize.height, 1)
        }
        return scroll
    }

    func updateNSView(_ scroll: FittingScrollView, context: Context) {
        context.coordinator.host?.rootView = content
        scroll.needsLayout = true
    }

    /// The scroll view must take the space the column offers. Reporting the
    /// document height here makes the window grow to the whole spell list.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: FittingScrollView, context: Context) -> CGSize? {
        CGSize(
            width: Self.finite(proposal.width, fallback: 320),
            height: Self.finite(proposal.height, fallback: 240)
        )
    }

    private static func finite(_ value: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let value, value.isFinite, value > 1 else { return fallback }
        return value
    }

    final class Coordinator {
        var host: NSHostingView<Content>?
    }
}

final class FittingScrollView: NSScrollView {
    var measureHeight: ((CGFloat) -> CGFloat)?
    private var measuring = false

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override var fittingSize: NSSize {
        if bounds.width > 1, bounds.height > 1 { return bounds.size }
        return NSSize(width: 320, height: 240)
    }

    override func setFrameSize(_ newSize: NSSize) {
        var size = newSize
        if let window, window.contentLayoutRect.height > 40, size.height > window.contentLayoutRect.height {
            size.height = window.contentLayoutRect.height
        }
        super.setFrameSize(size)
    }

    override func layout() {
        super.layout()
        guard !measuring, let document = documentView else { return }
        measuring = true
        defer { measuring = false }
        let width = max(contentView.bounds.width, 1)
        let height = max(measureHeight?(width) ?? document.fittingSize.height, 1)
        let size = NSSize(width: width, height: height)
        if abs(document.frame.width - size.width) > 0.5 || abs(document.frame.height - size.height) > 0.5 {
            document.setFrameSize(size)
            reflectScrolledClipView(contentView)
        }
        allowClicks(in: self)
    }

    private func allowClicks(in view: NSView) {
        for recognizer in view.gestureRecognizers {
            recognizer.delaysPrimaryMouseButtonEvents = false
        }
        for child in view.subviews {
            allowClicks(in: child)
        }
    }
}
