import AppKit
import SwiftUI

@main
struct VoltlineApp: App {
    @NSApplicationDelegateAdaptor(VoltlineAppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    init() {
        appDelegate.configure(model: model)
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(model)
                .task {
                    model.start()
                }
        }
        .defaultSize(width: 1120, height: 760)
    }
}

@MainActor
final class VoltlineAppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusItemController: StatusItemController?

    func configure(model: AppModel) {
        self.model = model
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let model {
            statusItemController = StatusItemController(model: model)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
