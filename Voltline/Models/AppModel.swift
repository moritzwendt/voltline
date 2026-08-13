import AppKit
import Foundation
import Observation
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct RecordedDay: Identifiable, Equatable {
    let date: Date
    let measurementCount: Int

    var id: Date {
        date
    }
}

@MainActor
@Observable
final class AppModel {
    private let container: ModelContainer
    private let context: ModelContext
    private let hardware = BatteryHardwareService()
    private let accessoryService = AccessoryBatteryService()
    private let enhancedBluetoothService = EnhancedBluetoothBatteryService()
    private let mobileDeviceService = MobileDeviceBatteryService()
    private var bleScanner: BLEAccessoryScanner?
    private var pollingTask: Task<Void, Never>?
    private var accessoryPollingTask: Task<Void, Never>?
    private var accessoryScanTask: Task<Void, Never>?
    private var eventBridge: BatteryEventBridge?
    private var bluetoothConnectionBridge: BluetoothConnectionBridge?
    private var activeSession: PowerSessionRecord?
    private var currentSessionID = UUID()
    private var systemSleeping = false
    private var started = false

    var currentSnapshot: BatterySnapshot?
    var samples: [BatterySamplePoint] = []
    var recordedDays: [RecordedDay] = []
    var selectedDate: Date = .now
    var lastUpdated: Date?
    var accessories: [BatteryDevice] = []
    var lastImportResult: String?
    var monitoringEnabled = true {
        didSet {
            UserDefaults.standard.set(monitoringEnabled, forKey: "monitoringEnabled")
            restartPolling()
        }
    }
    var collectDisplayActivity = true {
        didSet {
            UserDefaults.standard.set(collectDisplayActivity, forKey: "collectDisplayActivity")
        }
    }
    var accessoryMonitoringEnabled = true {
        didSet {
            UserDefaults.standard.set(accessoryMonitoringEnabled, forKey: "accessoryMonitoringEnabled")
            if accessoryMonitoringEnabled {
                refreshAccessories()
            }
            restartAccessoryPolling()
            updateBLEScanner()
        }
    }
    var accessoryRefreshSeconds = 60 {
        didSet {
            accessoryRefreshSeconds = min(max(accessoryRefreshSeconds, 30), 300)
            UserDefaults.standard.set(accessoryRefreshSeconds, forKey: "accessoryRefreshSeconds")
            restartAccessoryPolling()
        }
    }
    var discoverBluetoothLowEnergy = true {
        didSet {
            UserDefaults.standard.set(discoverBluetoothLowEnergy, forKey: "discoverBluetoothLowEnergy")
            updateBLEScanner()
        }
    }
    var discoverGenericBLE = true {
        didSet {
            UserDefaults.standard.set(discoverGenericBLE, forKey: "discoverGenericBLE")
            updateBLEScanner()
        }
    }
    var discoverMobileDevices = true {
        didSet {
            UserDefaults.standard.set(discoverMobileDevices, forKey: "discoverMobileDevices")
            refreshAccessories()
        }
    }
    var discoverEnhancedBluetooth = true {
        didSet {
            UserDefaults.standard.set(discoverEnhancedBluetooth, forKey: "discoverEnhancedBluetooth")
            refreshAccessories()
        }
    }
    var accessoryOfflineMinutes = 20 {
        didSet {
            if accessoryOfflineMinutes != Int.max {
                accessoryOfflineMinutes = min(max(accessoryOfflineMinutes, 1), 120)
            }
            UserDefaults.standard.set(accessoryOfflineMinutes, forKey: "accessoryOfflineMinutes")
            pruneAccessories()
        }
    }
    var earbudMergeDifference = 3 {
        didSet {
            earbudMergeDifference = min(max(earbudMergeDifference, 0), 20)
            UserDefaults.standard.set(earbudMergeDifference, forKey: "earbudMergeDifference")
            refreshAccessories()
            updateBLEScanner()
        }
    }
    var lowBatteryAlertsEnabled = false {
        didSet {
            UserDefaults.standard.set(lowBatteryAlertsEnabled, forKey: "lowBatteryAlertsEnabled")
            if lowBatteryAlertsEnabled {
                requestNotificationAccess()
            }
        }
    }
    var lowBatteryAlertLevel = 20 {
        didSet {
            lowBatteryAlertLevel = min(max(lowBatteryAlertLevel, 5), 50)
            UserDefaults.standard.set(lowBatteryAlertLevel, forKey: "lowBatteryAlertLevel")
        }
    }
    var lastError: String?
    let demoMode: Bool
    private var pinnedDeviceIDs: Set<String>
    private var hiddenDeviceIDs: Set<String>
    private var alertedDeviceLevels: [String: Int] = [:]

    init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
        pinnedDeviceIDs = Set(UserDefaults.standard.stringArray(forKey: "pinnedDeviceIDs") ?? [])
        hiddenDeviceIDs = Set(UserDefaults.standard.stringArray(forKey: "hiddenDeviceIDs") ?? [])
        demoMode = UserDefaults.standard.bool(forKey: "VoltlinePreviewData") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if UserDefaults.standard.object(forKey: "monitoringEnabled") != nil {
            monitoringEnabled = UserDefaults.standard.bool(forKey: "monitoringEnabled")
        }
        if UserDefaults.standard.object(forKey: "collectDisplayActivity") != nil {
            collectDisplayActivity = UserDefaults.standard.bool(forKey: "collectDisplayActivity")
        }
        if UserDefaults.standard.object(forKey: "accessoryMonitoringEnabled") != nil {
            accessoryMonitoringEnabled = UserDefaults.standard.bool(forKey: "accessoryMonitoringEnabled")
        }
        if let value = UserDefaults.standard.object(forKey: "accessoryRefreshSeconds") as? Int {
            accessoryRefreshSeconds = value
        }
        if UserDefaults.standard.object(forKey: "discoverBluetoothLowEnergy") != nil {
            discoverBluetoothLowEnergy = UserDefaults.standard.bool(forKey: "discoverBluetoothLowEnergy")
        }
        if UserDefaults.standard.object(forKey: "discoverGenericBLE") != nil {
            discoverGenericBLE = UserDefaults.standard.bool(forKey: "discoverGenericBLE")
        }
        if UserDefaults.standard.object(forKey: "discoverMobileDevices") != nil {
            discoverMobileDevices = UserDefaults.standard.bool(forKey: "discoverMobileDevices")
        }
        if UserDefaults.standard.object(forKey: "discoverEnhancedBluetooth") != nil {
            discoverEnhancedBluetooth = UserDefaults.standard.bool(forKey: "discoverEnhancedBluetooth")
        }
        if let value = UserDefaults.standard.object(forKey: "accessoryOfflineMinutes") as? Int {
            accessoryOfflineMinutes = value
        }
        if let value = UserDefaults.standard.object(forKey: "earbudMergeDifference") as? Int {
            earbudMergeDifference = value
        }
        if UserDefaults.standard.object(forKey: "lowBatteryAlertsEnabled") != nil {
            lowBatteryAlertsEnabled = UserDefaults.standard.bool(forKey: "lowBatteryAlertsEnabled")
        }
        if let value = UserDefaults.standard.object(forKey: "lowBatteryAlertLevel") as? Int {
            lowBatteryAlertLevel = value
        }
        if let data = UserDefaults.standard.data(forKey: "accessoryCache"),
           let cached = try? JSONDecoder().decode([BatteryDevice].self, from: data) {
            if accessoryOfflineMinutes == Int.max {
                accessories = cached
            } else {
                let expiration = Date.now.addingTimeInterval(Double(accessoryOfflineMinutes) * -60)
                accessories = cached.filter { $0.lastSeen >= expiration }
            }
        }
        if demoMode {
            let demoSamples = SampleData.typicalWorkday()
            samples = demoSamples
            if let last = demoSamples.last {
                currentSnapshot = BatterySnapshot(
                    timestamp: last.timestamp,
                    percentage: last.batteryLevel,
                    powerSource: last.powerSource,
                    chargingState: last.chargingState,
                    systemTimeRemaining: last.systemEstimate,
                    timeUntilFull: .unavailable,
                    lowPowerModeEnabled: last.lowPowerModeEnabled,
                    displayActive: last.displayActive,
                    systemSleeping: last.systemSleeping,
                    warningState: .unavailable,
                    electrical: last.electrical
                )
                lastUpdated = last.timestamp
            }
            accessories = SampleData.accessories
        }
    }

    func start() {
        guard !started else {
            return
        }
        started = true
        eventBridge = BatteryEventBridge(model: self)
        bluetoothConnectionBridge = BluetoothConnectionBridge { [weak self] in
            self?.refreshAccessories()
        }
        if !demoMode {
            refresh(persist: monitoringEnabled)
            loadSamples(for: selectedDate)
            loadRecordedDays()
            restartPolling()
            refreshAccessories()
            restartAccessoryPolling()
            updateBLEScanner()
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        if demoMode {
            samples = SampleData.typicalWorkday(day: date)
        } else {
            loadSamples(for: date)
        }
    }

    func refresh(persist: Bool = true) {
        guard !demoMode else {
            return
        }
        do {
            var snapshot = try hardware.readSnapshot(systemSleeping: systemSleeping)
            if !collectDisplayActivity {
                snapshot = BatterySnapshot(
                    timestamp: snapshot.timestamp,
                    percentage: snapshot.percentage,
                    powerSource: snapshot.powerSource,
                    chargingState: snapshot.chargingState,
                    systemTimeRemaining: snapshot.systemTimeRemaining,
                    timeUntilFull: snapshot.timeUntilFull,
                    lowPowerModeEnabled: snapshot.lowPowerModeEnabled,
                    displayActive: false,
                    systemSleeping: snapshot.systemSleeping,
                    warningState: snapshot.warningState,
                    electrical: snapshot.electrical
                )
            }
            let previous = currentSnapshot
            currentSnapshot = snapshot
            lastUpdated = snapshot.timestamp
            lastError = nil
            if persist {
                persistSnapshot(snapshot, previous: previous)
            }
        } catch {
            lastError = "Battery data is unavailable on this Mac."
        }
    }

    func handleSystemSleep(_ sleeping: Bool) {
        systemSleeping = sleeping
        refresh(persist: monitoringEnabled)
        if !sleeping {
            refreshAccessories()
        }
    }

    func handleSystemEvent() {
        refresh(persist: monitoringEnabled)
        refreshAccessories()
    }

    var visibleAccessories: [BatteryDevice] {
        accessories
            .filter { !hiddenDeviceIDs.contains($0.id) }
            .sorted { left, right in
                let leftPinned = pinnedDeviceIDs.contains(left.id)
                let rightPinned = pinnedDeviceIDs.contains(right.id)
                if leftPinned != rightPinned {
                    return leftPinned
                }
                return left.displayName.localizedStandardCompare(right.displayName) == .orderedAscending
            }
    }

    var hiddenAccessories: [BatteryDevice] {
        accessories.filter { hiddenDeviceIDs.contains($0.id) }
    }

    func isPinned(_ device: BatteryDevice) -> Bool {
        pinnedDeviceIDs.contains(device.id)
    }

    func togglePin(_ device: BatteryDevice) {
        if pinnedDeviceIDs.contains(device.id) {
            pinnedDeviceIDs.remove(device.id)
        } else {
            pinnedDeviceIDs.insert(device.id)
        }
        UserDefaults.standard.set(Array(pinnedDeviceIDs), forKey: "pinnedDeviceIDs")
    }

    func hide(_ device: BatteryDevice) {
        hiddenDeviceIDs.insert(device.id)
        UserDefaults.standard.set(Array(hiddenDeviceIDs), forKey: "hiddenDeviceIDs")
    }

    func show(_ device: BatteryDevice) {
        hiddenDeviceIDs.remove(device.id)
        UserDefaults.standard.set(Array(hiddenDeviceIDs), forKey: "hiddenDeviceIDs")
    }

    func refreshAccessories() {
        guard accessoryMonitoringEnabled, !demoMode, accessoryScanTask == nil else {
            return
        }
        let service = accessoryService
        let enhancedService = enhancedBluetoothService
        let mobileService = mobileDeviceService
        let mergeDifference = earbudMergeDifference
        let readsMobileDevices = discoverMobileDevices
        let readsEnhancedBluetooth = discoverEnhancedBluetooth
        accessoryScanTask = Task { [weak self] in
            let found = await Task.detached(priority: .utility) {
                var devices = service.scan(earbudMergeDifference: mergeDifference)
                if readsEnhancedBluetooth {
                    devices.append(contentsOf: enhancedService.scan())
                }
                if readsMobileDevices {
                    devices.append(contentsOf: mobileService.scan())
                }
                return devices
            }.value
            guard let self, !Task.isCancelled else {
                return
            }
            self.mergeAccessories(found)
            self.accessoryScanTask = nil
        }
        bleScanner?.scan()
    }

    var recentRate: Double? {
        BatteryAnalytics.dischargeRate(samples: samples, window: 3600, referenceDate: currentSnapshot?.timestamp)
    }

    var shortRate: Double? {
        BatteryAnalytics.dischargeRate(samples: samples, window: 900, referenceDate: currentSnapshot?.timestamp)
    }

    var derivedRuntime: TimeInterval? {
        guard let snapshot = currentSnapshot else {
            return nil
        }
        return BatteryAnalytics.derivedRuntime(level: snapshot.percentage, rate: recentRate)
    }

    var dayMetrics: BatteryDayMetrics {
        BatteryAnalytics.dayMetrics(samples: samples)
    }

    var oldestMeasurement: Date? {
        var descriptor = FetchDescriptor<BatterySampleRecord>(sortBy: [SortDescriptor(\.timestamp)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.timestamp
    }

    var storedMeasurementCount: Int {
        (try? context.fetchCount(FetchDescriptor<BatterySampleRecord>())) ?? 0
    }

    var latestRecordedDate: Date? {
        recordedDays.first?.date
    }

    func powerSamples(from start: Date, through end: Date) -> [BatterySamplePoint] {
        if demoMode {
            return PowerAnalytics.samples(samples, from: start, through: end)
        }
        let descriptor = FetchDescriptor<BatterySampleRecord>(
            predicate: #Predicate { record in
                record.timestamp >= start && record.timestamp <= end
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        do {
            return try context.fetch(descriptor).map(\.point)
        } catch {
            lastError = "Power history could not be loaded."
            return []
        }
    }

    func selectLatestRecordedDay() {
        guard let latestRecordedDate else {
            return
        }
        selectDate(latestRecordedDate)
    }

    func importLegacyHistory() {
        let panel = NSOpenPanel()
        panel.title = "Import old Voltline history"
        panel.prompt = "Import"
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        panel.nameFieldStringValue = "default.store"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        guard !container.configurations.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else {
            lastError = "Choose an older Voltline history store."
            return
        }

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let result = try LegacyHistoryImporter.importStore(at: url, into: context)
            loadRecordedDays()
            loadSamples(for: selectedDate)
            lastImportResult = result.measurements == 1
                ? "Imported 1 measurement"
                : "Imported \(result.measurements.formatted()) measurements"
            lastError = nil
        } catch {
            lastImportResult = nil
            lastError = "The selected history store could not be imported."
        }
    }

    func exportCSV() {
        let descriptor = FetchDescriptor<BatterySampleRecord>(sortBy: [SortDescriptor(\.timestamp)])
        guard let records = try? context.fetch(descriptor) else {
            lastError = "History could not be prepared for export."
            return
        }
        let formatter = ISO8601DateFormatter()
        var rows = ["timestamp,battery_percentage,is_charging,power_source,low_power_mode,display_active,system_estimated_seconds,voltage_volts,amperage_amps,battery_power_watts,adapter_power_watts,system_power_watts,temperature_celsius,current_capacity_mah,full_charge_capacity_mah,design_capacity_mah,cycle_count,battery_condition,adapter_capacity_watts,adapter_identity,connection_type"]
        rows.append(contentsOf: records.map { record in
            let charging = record.chargingStateRaw == ChargingState.charging.rawValue
            return [
                formatter.string(from: record.timestamp),
                String(format: "%.2f", record.batteryLevel),
                String(charging),
                record.powerSourceRaw,
                String(record.lowPowerModeEnabled),
                String(record.displayActive),
                record.estimateSeconds.map { String($0) } ?? "",
                Self.csvNumber(record.voltageVolts),
                Self.csvNumber(record.amperageAmps),
                Self.csvNumber(record.batteryPowerWatts),
                Self.csvNumber(record.adapterPowerWatts),
                Self.csvNumber(record.systemPowerWatts),
                Self.csvNumber(record.temperatureCelsius),
                Self.csvNumber(record.currentCapacityMilliampHours),
                Self.csvNumber(record.fullChargeCapacityMilliampHours),
                Self.csvNumber(record.designCapacityMilliampHours),
                record.cycleCount.map(String.init) ?? "",
                Self.csvText(record.batteryCondition),
                Self.csvNumber(record.adapterCapacityWatts),
                Self.csvText(record.adapterIdentity),
                record.connectionTypeRaw ?? ""
            ].joined(separator: ",")
        })
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Voltline battery history.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            lastError = "The export could not be saved."
        }
    }

    private static func csvNumber(_ value: Double?) -> String {
        value.map { String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? ""
    }

    private static func csvText(_ value: String?) -> String {
        guard let value else {
            return ""
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    func deleteAllHistory() {
        do {
            try context.delete(model: BatterySampleRecord.self)
            try context.delete(model: PowerSessionRecord.self)
            try context.delete(model: DailySummaryRecord.self)
            try context.save()
            samples = []
            recordedDays = []
            activeSession = nil
            currentSessionID = UUID()
            lastImportResult = nil
        } catch {
            lastError = "History could not be deleted."
        }
    }

    private func restartPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        guard monitoringEnabled, !demoMode else {
            return
        }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                let interval: TimeInterval = self.currentSnapshot?.powerSource == .battery ? 45 : 180
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                self.refresh()
            }
        }
    }

    private func restartAccessoryPolling() {
        accessoryPollingTask?.cancel()
        accessoryPollingTask = nil
        guard accessoryMonitoringEnabled, !demoMode else {
            return
        }
        accessoryPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                do {
                    try await Task.sleep(for: .seconds(self.accessoryRefreshSeconds))
                } catch {
                    return
                }
                self.refreshAccessories()
            }
        }
        updateBLEScanner()
    }

    private func updateBLEScanner() {
        guard started, !demoMode else {
            return
        }
        if bleScanner == nil {
            let scanner = BLEAccessoryScanner()
            scanner.onDevicesChanged = { [weak self] devices in
                self?.mergeAccessories(devices)
            }
            bleScanner = scanner
        }
        guard let bleScanner else {
            return
        }
        bleScanner.isEnabled = accessoryMonitoringEnabled && discoverBluetoothLowEnergy
        bleScanner.readsGenericDevices = discoverGenericBLE
        bleScanner.readsIOSDevices = discoverMobileDevices
        bleScanner.earbudMergeDifference = earbudMergeDifference
        if bleScanner.isEnabled {
            bleScanner.start(interval: TimeInterval(accessoryRefreshSeconds))
        } else {
            bleScanner.stop()
        }
    }

    private func mergeAccessories(_ found: [BatteryDevice]) {
        let retained: [BatteryDevice]
        if accessoryOfflineMinutes == Int.max {
            retained = accessories
        } else {
            let expiration = Date.now.addingTimeInterval(Double(accessoryOfflineMinutes) * -60)
            retained = accessories.filter { $0.lastSeen >= expiration }
        }
        var merged = Dictionary(uniqueKeysWithValues: retained.map { ($0.id, $0) })
        for device in found {
            let duplicateIDs = merged.values.filter {
                $0.id != device.id && normalizedDeviceName($0.displayName) == normalizedDeviceName(device.displayName)
            }.map(\.id)
            for id in duplicateIDs {
                merged.removeValue(forKey: id)
            }
            merged[device.id] = device
        }
        let grouped = Dictionary(grouping: found, by: { normalizedDeviceName($0.name) })
        for (name, updates) in grouped {
            let components = Set(updates.compactMap(\.component))
            if components.contains("Earbuds") {
                merged = merged.filter {
                    normalizedDeviceName($0.value.name) != name || ($0.value.component != "Left" && $0.value.component != "Right")
                }
            } else if components.contains("Left") && components.contains("Right") {
                merged = merged.filter {
                    normalizedDeviceName($0.value.name) != name || $0.value.component != "Earbuds"
                }
            }
        }
        accessories = Array(merged.values)
        if let data = try? JSONEncoder().encode(accessories) {
            UserDefaults.standard.set(data, forKey: "accessoryCache")
        }
        evaluateAlerts(for: found)
    }

    private func normalizedDeviceName(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func pruneAccessories() {
        guard accessoryOfflineMinutes != Int.max else {
            return
        }
        let expiration = Date.now.addingTimeInterval(Double(accessoryOfflineMinutes) * -60)
        accessories.removeAll { $0.lastSeen < expiration }
        if let data = try? JSONEncoder().encode(accessories) {
            UserDefaults.standard.set(data, forKey: "accessoryCache")
        }
    }

    private func requestNotificationAccess() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    private func evaluateAlerts(for devices: [BatteryDevice]) {
        guard lowBatteryAlertsEnabled else {
            return
        }
        for device in devices {
            if device.level > lowBatteryAlertLevel {
                alertedDeviceLevels.removeValue(forKey: device.id)
                continue
            }
            guard alertedDeviceLevels[device.id] != device.level else {
                continue
            }
            alertedDeviceLevels[device.id] = device.level
            let content = UNMutableNotificationContent()
            content.title = "Low battery"
            content.body = "\(device.displayName) is at \(device.level)%"
            content.sound = .default
            let request = UNNotificationRequest(identifier: "voltline|\(device.id)|\(device.level)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func persistSnapshot(_ snapshot: BatterySnapshot, previous: BatterySnapshot?) {
        if let previous, snapshot.timestamp.timeIntervalSince(previous.timestamp) < 10,
           previous.powerSource == snapshot.powerSource,
           previous.chargingState == snapshot.chargingState,
           previous.lowPowerModeEnabled == snapshot.lowPowerModeEnabled,
           previous.displayActive == snapshot.displayActive,
           previous.systemSleeping == snapshot.systemSleeping {
            return
        }

        let transition = previous == nil || previous?.powerSource != snapshot.powerSource || previous?.chargingState != snapshot.chargingState || previous?.systemSleeping != snapshot.systemSleeping
        if transition {
            activeSession?.endedAt = snapshot.timestamp
            activeSession?.endingLevel = snapshot.percentage
            currentSessionID = UUID()
            let session = PowerSessionRecord(
                id: currentSessionID,
                startedAt: snapshot.timestamp,
                category: snapshot.powerSource,
                startingLevel: snapshot.percentage
            )
            context.insert(session)
            activeSession = session
        } else {
            activeSession?.endedAt = snapshot.timestamp
            activeSession?.endingLevel = snapshot.percentage
        }

        context.insert(BatterySampleRecord(snapshot: snapshot, sessionID: currentSessionID))
        do {
            try context.save()
            if Calendar.current.isDate(snapshot.timestamp, inSameDayAs: selectedDate) {
                loadSamples(for: selectedDate)
            }
            loadRecordedDays()
        } catch {
            lastError = "The latest measurement could not be saved."
        }
    }

    private func loadSamples(for date: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return
        }
        let descriptor = FetchDescriptor<BatterySampleRecord>(
            predicate: #Predicate { record in
                record.timestamp >= start && record.timestamp < end
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        do {
            samples = try context.fetch(descriptor).map(\.point)
        } catch {
            lastError = "History for this day could not be loaded."
        }
    }

    private func loadRecordedDays() {
        var descriptor = FetchDescriptor<BatterySampleRecord>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.propertiesToFetch = [\.timestamp]
        do {
            let calendar = Calendar.current
            let counts = try context.fetch(descriptor).reduce(into: [Date: Int]()) { result, record in
                result[calendar.startOfDay(for: record.timestamp), default: 0] += 1
            }
            recordedDays = counts.map { RecordedDay(date: $0.key, measurementCount: $0.value) }
                .sorted { $0.date > $1.date }
        } catch {
            lastError = "Recorded days could not be loaded."
        }
    }
}

@MainActor
private final class BatteryEventBridge: NSObject {
    private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displayChanged), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displayChanged), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    @objc private func powerStateChanged() {
        model?.handleSystemEvent()
    }

    @objc private func willSleep() {
        model?.handleSystemSleep(true)
    }

    @objc private func didWake() {
        model?.handleSystemSleep(false)
    }

    @objc private func displayChanged() {
        model?.handleSystemEvent()
    }
}
