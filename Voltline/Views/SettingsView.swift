import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("menuBarDynamicIcon") private var dynamicIcon = true
    @AppStorage("menuBarPercentageMode") private var percentageMode = MenuBarPercentageMode.outside.rawValue
    @AppStorage("menuBarColorful") private var colorfulIcon = false
    @AppStorage("menuBarIOSShape") private var iosShape = false
    @AppStorage("menuBarHidePercentageAbove") private var hidePercentageAbove = 100.0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Monitoring") {
                Toggle("Track battery measurements", isOn: $model.monitoringEnabled)
                Picker("Refresh interval", selection: $model.refreshInterval) {
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("5 minutes").tag(TimeInterval(300))
                }
            }

            Section("Application") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLoginItem(enabled)
                    }
            }

            Section("Menu bar") {
                Toggle("Show menu bar item", isOn: $showMenuBar)
                Toggle("Dynamic battery icon", isOn: $dynamicIcon)
                Toggle("Colorful icon", isOn: $colorfulIcon)
                Toggle("iOS battery shape", isOn: $iosShape)
                Picker("Percentage", selection: $percentageMode) {
                    ForEach(MenuBarPercentageMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                Slider(value: $hidePercentageAbove, in: 50 ... 100, step: 5) {
                    Text("Hide percentage above")
                }
            }

            Section("Devices") {
                Stepper("Remove offline devices after \(model.accessoryOfflineMinutes) minutes", value: $model.accessoryOfflineMinutes, in: 5 ... 120, step: 5)
                ForEach(model.visibleAccessories) { device in
                    HStack {
                        Text(device.name)
                        Spacer()
                        Button("Hide") {
                            model.hide(device)
                        }
                    }
                }
                ForEach(model.hiddenAccessories) { device in
                    HStack {
                        Text(device.name)
                        Spacer()
                        Button("Show") {
                            model.show(device)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 320)
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
