import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("menuBarDynamicIcon") private var menuBarDynamicIcon = true
    @AppStorage("menuBarPercentageMode") private var menuBarPercentageMode = MenuBarPercentageMode.outside.rawValue
    @AppStorage("menuBarColorful") private var menuBarColorful = false
    @AppStorage("menuBarIOSShape") private var menuBarIOSShape = false
    @AppStorage("menuBarHidePercentageAbove") private var menuBarHidePercentageAbove = 90.0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showingDeleteConfirmation = false
    @State private var serviceError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                settingsSection("General", symbol: "slider.horizontal.3") {
                    Toggle("Monitor battery in the background", isOn: Binding(
                        get: { model.monitoringEnabled },
                        set: { model.monitoringEnabled = $0 }
                    ))
                    Toggle("Show Voltline in the menu bar", isOn: $showMenuBar)
                    Toggle("Launch Voltline at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            updateLoginItem(enabled)
                        }
                }

                settingsSection("Menu bar", symbol: "menubar.rectangle") {
                    Toggle("Dynamic battery icon", isOn: $menuBarDynamicIcon)
                    Toggle("Colorful battery icon", isOn: $menuBarColorful)
                        .disabled(!menuBarDynamicIcon)
                    Picker("Battery icon style", selection: $menuBarIOSShape) {
                        Text("macOS").tag(false)
                        Text("iOS").tag(true)
                    }
                    .disabled(!menuBarDynamicIcon)
                    Picker("Show percentage", selection: $menuBarPercentageMode) {
                        ForEach(MenuBarPercentageMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .disabled(!menuBarDynamicIcon)
                    Picker("Remove offline device", selection: Binding(
                        get: { model.accessoryOfflineMinutes },
                        set: { model.accessoryOfflineMinutes = $0 }
                    )) {
                        Text("Never").tag(Int.max)
                        Text("After 20 minutes").tag(20)
                        Text("After 40 minutes").tag(40)
                        Text("After 60 minutes").tag(60)
                    }
                    Picker("Hide percentage when above", selection: $menuBarHidePercentageAbove) {
                        Text("Never").tag(100.0)
                        ForEach([95.0, 90, 80, 70, 60, 50, 40, 30, 20, 10], id: \.self) { level in
                            Text("\(Int(level))%").tag(level)
                        }
                    }
                    .disabled(!menuBarDynamicIcon || menuBarPercentageMode == MenuBarPercentageMode.hidden.rawValue)
                }

                settingsSection("Devices", symbol: "airpodspro") {
                    Toggle("Monitor connected devices", isOn: Binding(
                        get: { model.accessoryMonitoringEnabled },
                        set: { model.accessoryMonitoringEnabled = $0 }
                    ))
                    Toggle("Discover Bluetooth devices", isOn: Binding(
                        get: { model.discoverBluetoothLowEnergy },
                        set: { model.discoverBluetoothLowEnergy = $0 }
                    ))
                    .disabled(!model.accessoryMonitoringEnabled)
                    Toggle("Read standard Bluetooth batteries", isOn: Binding(
                        get: { model.discoverGenericBLE },
                        set: { model.discoverGenericBLE = $0 }
                    ))
                    .disabled(!model.accessoryMonitoringEnabled || !model.discoverBluetoothLowEnergy)
                    Toggle("Discover more Bluetooth devices", isOn: Binding(
                        get: { model.discoverEnhancedBluetooth },
                        set: { model.discoverEnhancedBluetooth = $0 }
                    ))
                    .disabled(!model.accessoryMonitoringEnabled)
                    Toggle("Discover iPhone, iPad, and Apple Watch", isOn: Binding(
                        get: { model.discoverMobileDevices },
                        set: { model.discoverMobileDevices = $0 }
                    ))
                    .disabled(!model.accessoryMonitoringEnabled)
                    Picker("Refresh devices", selection: Binding(
                        get: { model.accessoryRefreshSeconds },
                        set: { model.accessoryRefreshSeconds = $0 }
                    )) {
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("5 minutes").tag(300)
                    }
                    Stepper("Merge earbuds within \(model.earbudMergeDifference)%", value: Binding(
                        get: { model.earbudMergeDifference },
                        set: { model.earbudMergeDifference = $0 }
                    ), in: 0...20)
                    Toggle("Low battery alerts", isOn: Binding(
                        get: { model.lowBatteryAlertsEnabled },
                        set: { model.lowBatteryAlertsEnabled = $0 }
                    ))
                    Stepper("Alert at \(model.lowBatteryAlertLevel)%", value: Binding(
                        get: { model.lowBatteryAlertLevel },
                        set: { model.lowBatteryAlertLevel = $0 }
                    ), in: 5...50, step: 5)
                    .disabled(!model.lowBatteryAlertsEnabled)
                    if !model.visibleAccessories.isEmpty {
                        Divider()
                        ForEach(model.visibleAccessories) { device in
                            HStack(spacing: 10) {
                                Label(device.displayName, systemImage: device.kind.symbol)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(device.level)%")
                                    .monospacedDigit()
                                Button {
                                    model.togglePin(device)
                                } label: {
                                    Image(systemName: model.isPinned(device) ? "pin.fill" : "pin")
                                }
                                .buttonStyle(.glass)
                                .accessibilityLabel(model.isPinned(device) ? "Unpin" : "Pin")
                                Button {
                                    model.hide(device)
                                } label: {
                                    Image(systemName: "eye.slash")
                                }
                                .buttonStyle(.glass)
                                .accessibilityLabel("Hide")
                            }
                        }
                    }
                    if !model.hiddenAccessories.isEmpty {
                        Divider()
                        ForEach(model.hiddenAccessories) { device in
                            HStack {
                                Label(device.displayName, systemImage: device.kind.symbol)
                                Spacer()
                                Button("Show") {
                                    model.show(device)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }

                settingsSection("Monitoring", symbol: "waveform.path.ecg") {
                    Toggle("Record display activity", isOn: Binding(
                        get: { model.collectDisplayActivity },
                        set: { model.collectDisplayActivity = $0 }
                    ))
                    LabeledContent("Sampling on battery", value: "Adaptive, about 45 seconds")
                    LabeledContent("Sampling on external power", value: "Adaptive, about 3 minutes")
                    LabeledContent("History retention", value: "Forever")
                }

                settingsSection("Data", symbol: "internaldrive") {
                    LabeledContent("Stored measurements", value: "\(model.storedMeasurementCount.formatted())")
                    LabeledContent("Oldest measurement", value: model.oldestMeasurement?.formatted(date: .abbreviated, time: .shortened) ?? "None yet")
                    HStack {
                        Button("Import old history") {
                            model.importLegacyHistory()
                        }
                        .buttonStyle(.glass)
                        Button("Export history") {
                            model.exportCSV()
                        }
                        .buttonStyle(.glass)
                        Spacer()
                        Button("Delete all history", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                    if let result = model.lastImportResult {
                        Label(result, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(VoltlineStyle.mint)
                    }
                }

                settingsSection("Data sources", symbol: "checkmark.shield") {
                    LabeledContent("Battery and power", value: "IOPowerSources")
                    LabeledContent("Low Power Mode", value: "Foundation")
                    LabeledContent("Display and sleep", value: "macOS events")
                    LabeledContent("Screen Time and app attribution", value: "Unavailable")
                }

                if let displayedError = serviceError ?? model.lastError {
                    Label(displayedError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(VoltlineStyle.alert)
                }
            }
            .padding(28)
        }
        .frame(width: 650, height: 720)
        .background(VoltlineStyle.canvas)
        .confirmationDialog(
            "Delete all recorded battery history?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete all history", role: .destructive) {
                model.deleteAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every measurement and session stored by Voltline.")
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: symbol)
                .font(.headline)
            VStack(alignment: .leading, spacing: 13) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .voltlinePanel(cornerRadius: 18)
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            serviceError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            serviceError = "Launch at login could not be changed while Voltline is running from Xcode."
        }
    }
}
