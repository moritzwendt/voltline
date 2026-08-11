import AppKit
import SwiftData
import SwiftUI

@main
struct VoltlineApp: App {
    @NSApplicationDelegateAdaptor(VoltlineAppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @State private var model: AppModel

    init() {
        do {
            let container = try VoltlinePersistence.makeContainer()
            let model = AppModel(container: container)
            self.container = container
            _model = State(initialValue: model)
            appDelegate.configure(model: model)
            model.start()
        } catch {
            fatalError("Voltline could not open its local history store.")
        }
    }

    var body: some Scene {
        WindowGroup(id: "dashboard") {
            AppShellView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        .defaultSize(width: 1240, height: 820)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }

}

final class VoltlineAppDelegate: NSObject, NSApplicationDelegate {
    private var activity: NSObjectProtocol?
    private var model: AppModel?
    private var statusItemController: StatusItemController?

    func configure(model: AppModel) {
        self.model = model
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.automaticTerminationDisabled, .suddenTerminationDisabled],
            reason: "Battery monitoring"
        )
        if let model {
            statusItemController = StatusItemController(model: model)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
