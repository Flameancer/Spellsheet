import SwiftUI

@main
struct SpellsheetApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(model: AppStore.shared)
                .frame(minWidth: 1040, minHeight: 680)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
        }
        .defaultSize(width: 1240, height: 820)
        .windowToolbarStyle(.unified)
    }
}
