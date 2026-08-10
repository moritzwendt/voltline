import AppKit
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppModel {
    private let hardware = BatteryHardwareService()
    private var currentSessionID = UUID()
    private var previousSnapshot: BatterySnapshot?
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private var pollingTask: Task<Void, Never>?
    private var eventBridge: BatteryEventBridge?
    private var bluetoothConnectionBridge: BluetoothConnectionBridge?
    private var bleScanner: BLEAccessoryScanner?
    private var systemSleeping = false

    var currentSnapshot: BatterySnapshot?
    var samples: [BatterySamplePoint] = []
    var selectedDate = Date.now
    var lastUpdated: Date?
    var lastError: String?
    var accessories: [BatteryDevice] = []
    var monitoringEnabled = true {
        didSet {
            restartPolling()
        }
    }
    var refreshInterval: TimeInterval = 60 {
        didSet {
            restartPolling()
        }
    }

    init() {
        do {
            modelContainer = try VoltlinePersistence.makeContainer()
        } catch {
            fatalError(error.localizedDescription)
        }
        modelContext = ModelContext(modelContainer)
        loadStoredSamples()
        refresh()
    }

    func start() {
        eventBridge = BatteryEventBridge(model: self)
        bluetoothConnectionBridge = BluetoothConnectionBridge { [weak self] in
            self?.refreshAccessories()
        }
        let scanner = BLEAccessoryScanner()
        scanner.onDevicesChanged = { [weak self] devices in
            self?.mergeAccessories(devices)
        }
        scanner.start(interval: 60)
        bleScanner = scanner
        restartPolling()
        refreshAccessories()
    }

    private func restartPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        guard monitoringEnabled else {
            return
        }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                try? await Task.sleep(for: .seconds(self.refreshInterval))
                self.refresh()
            }
        }
    }

    func refresh() {
        do {
            let snapshot = try hardware.readSnapshot(systemSleeping: systemSleeping)
            if let previousSnapshot,
               previousSnapshot.powerSource != snapshot.powerSource || previousSnapshot.chargingState != snapshot.chargingState {
                currentSessionID = UUID()
            }
            currentSnapshot = snapshot
            lastUpdated = snapshot.timestamp
            lastError = nil
            samples.append(BatterySamplePoint(
                id: UUID(),
                timestamp: snapshot.timestamp,
                batteryLevel: snapshot.percentage,
                powerSource: snapshot.powerSource,
                chargingState: snapshot.chargingState,
                systemEstimate: snapshot.systemTimeRemaining,
                lowPowerModeEnabled: snapshot.lowPowerModeEnabled,
                displayActive: snapshot.displayActive,
                systemSleeping: snapshot.systemSleeping,
                sessionID: currentSessionID
            ))
            modelContext.insert(BatterySampleRecord(snapshot: snapshot, sessionID: currentSessionID))
            try modelContext.save()
            previousSnapshot = snapshot
        } catch {
            lastError = error.localizedDescription
        }
    }

    func handleSystemSleep(_ sleeping: Bool) {
        systemSleeping = sleeping
        if !sleeping {
            refresh()
            restartPolling()
        }
    }

    func refreshAccessories() {
        var found = AccessoryBatteryService().scan()
        found.append(contentsOf: EnhancedBluetoothBatteryService().scan())
        mergeAccessories(found)
    }

    private func mergeAccessories(_ found: [BatteryDevice]) {
        var merged = Dictionary(uniqueKeysWithValues: accessories.map { ($0.id, $0) })
        for device in found {
            merged[device.id] = device
        }
        accessories = merged.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var recentRate: Double? {
        BatteryAnalytics.dischargeRate(samples: samples, window: 3 * 3600)
    }

    var derivedRuntime: TimeInterval? {
        guard let currentSnapshot else {
            return nil
        }
        return BatteryAnalytics.derivedRuntime(level: currentSnapshot.percentage, rate: recentRate)
    }

    var dayMetrics: BatteryDayMetrics {
        BatteryAnalytics.dayMetrics(samples: samplesForSelectedDay)
    }

    var samplesForSelectedDay: [BatterySamplePoint] {
        samples.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDate) }
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    private func loadStoredSamples() {
        var descriptor = FetchDescriptor<BatterySampleRecord>()
        descriptor.sortBy = [SortDescriptor(\BatterySampleRecord.timestamp)]
        do {
            samples = try modelContext.fetch(descriptor).map(\.point)
        } catch {
            lastError = error.localizedDescription
        }
    }
}

@MainActor
private final class BatteryEventBridge: NSObject {
    private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
        super.init()
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func willSleep() {
        model?.handleSystemSleep(true)
    }

    @objc private func didWake() {
        model?.handleSystemSleep(false)
    }
}
