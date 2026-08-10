import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var timer: Timer?
    private var defaultsObserver: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        super.init()
        popover.contentViewController = NSHostingController(rootView: MenuBarView().environment(model))
        popover.behavior = .transient
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.image = NSImage(systemSymbolName: "battery.100percent", accessibilityDescription: "Voltline")
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshLayout()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshLayout()
            }
        }
        refreshLayout()
    }

    private func refreshLayout() {
        let defaults = UserDefaults.standard
        statusItem.isVisible = defaults.object(forKey: "showMenuBar") as? Bool ?? true
        guard let snapshot = model.currentSnapshot else {
            statusItem.button?.title = ""
            return
        }
        let mode = defaults.string(forKey: "menuBarPercentageMode") ?? MenuBarPercentageMode.outside.rawValue
        let threshold = defaults.object(forKey: "menuBarHidePercentageAbove") as? Double ?? 100
        let level = Int(snapshot.percentage.rounded())
        statusItem.button?.title = mode == MenuBarPercentageMode.outside.rawValue && Double(level) <= threshold ? " \(level)%" : ""
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
