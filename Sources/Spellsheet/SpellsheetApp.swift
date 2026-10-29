import SwiftUI

@main
struct SpellsheetApp: App {
    private var model: AppModel { AppStore.shared }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .frame(minWidth: 1040, minHeight: 680)
                .preferredColorScheme(model.colorTheme.palette.prefersDark ? .dark : .light)
                .tint(Theme.gold)
        }
        .defaultSize(width: 1240, height: 820)
        .windowToolbarStyle(.unified)
    }
}
