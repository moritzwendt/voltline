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

    var currentSnapshot: BatterySnapshot?
    var samples: [BatterySamplePoint] = []
    var selectedDate = Date.now
    var lastUpdated: Date?
    var lastError: String?
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
        restartPolling()
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
            let snapshot = try hardware.readSnapshot()
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
