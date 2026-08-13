import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var hostingView: NSHostingView<StatusItemContent>?
    private var timer: Timer?
    private var defaultsObserver: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        super.init()
        configureStatusItem()
        configurePopover()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshLayout()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshLayout()
            }
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
        button.image = NSImage()
        button.toolTip = "Voltline"
        refreshLayout()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
    }

    private func refreshLayout() {
        let defaults = UserDefaults.standard
        let visible = defaults.object(forKey: "showMenuBar") == nil || defaults.bool(forKey: "showMenuBar")
        statusItem.isVisible = visible
        guard visible, let button = statusItem.button else {
            return
        }

        let dynamic = defaults.object(forKey: "menuBarDynamicIcon") == nil || defaults.bool(forKey: "menuBarDynamicIcon")
        let mode = MenuBarPercentageMode(rawValue: defaults.string(forKey: "menuBarPercentageMode") ?? "outside") ?? .outside
        let threshold = defaults.object(forKey: "menuBarHidePercentageAbove") as? Double ?? 90
        let level = model.currentSnapshot?.percentage ?? 0
        let showsOutside = dynamic && mode == .outside && level <= threshold
        let width: CGFloat = if !dynamic {
            36
        } else if showsOutside {
            76
        } else {
            42
        }

        if statusItem.length != width || hostingView == nil {
            statusItem.length = width
            hostingView?.removeFromSuperview()
            let view = NSHostingView(rootView: StatusItemContent(model: model))
            view.frame = NSRect(x: 0, y: 0, width: width, height: 22)
            view.autoresizingMask = [.width, .height]
            button.addSubview(view)
            button.frame = view.frame
            hostingView = view
        }
        button.setAccessibilityLabel("Voltline battery \(Int(level.rounded())) percent")
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environment(model)
                .preferredColorScheme(.dark)
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

private struct StatusItemContent: View {
    @Bindable var model: AppModel
    @AppStorage("menuBarDynamicIcon") private var dynamicIcon = true
    @AppStorage("menuBarPercentageMode") private var percentageMode = MenuBarPercentageMode.outside.rawValue
    @AppStorage("menuBarColorful") private var colorful = false
    @AppStorage("menuBarIOSShape") private var iosShape = false
    @AppStorage("menuBarHidePercentageAbove") private var hidePercentageAbove = 90.0

    var body: some View {
        Group {
            if dynamicIcon {
                MenuBarBatteryIcon(
                    level: model.currentSnapshot?.percentage ?? 0,
                    isCharging: model.currentSnapshot?.isCharging ?? false,
                    isConnectedToPower: model.currentSnapshot?.isConnectedToPower ?? false,
                    percentageMode: MenuBarPercentageMode(rawValue: percentageMode) ?? .outside,
                    colorful: colorful,
                    iosShape: iosShape,
                    hidePercentageAbove: hidePercentageAbove
                )
            } else {
                Image(systemName: "bolt.square.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(false)
    }
}
