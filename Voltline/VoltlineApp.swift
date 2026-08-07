import SwiftUI

@main
struct VoltlineApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(model)
        }
        .defaultSize(width: 1120, height: 760)
    }
}

