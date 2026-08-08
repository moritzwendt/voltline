import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppModel {
    private let hardware = BatteryHardwareService()
    private let sessionID = UUID()
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private var pollingTask: Task<Void, Never>?

    var currentSnapshot: BatterySnapshot?
    var samples: [BatterySamplePoint] = []
    var lastUpdated: Date?
    var lastError: String?
    var monitoringEnabled = true

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
        guard pollingTask == nil else {
            return
        }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, self.monitoringEnabled else {
                    continue
                }
                self.refresh()
            }
        }
    }

    func refresh() {
        do {
            let snapshot = try hardware.readSnapshot()
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
                sessionID: sessionID
            ))
            modelContext.insert(BatterySampleRecord(snapshot: snapshot, sessionID: sessionID))
            try modelContext.save()
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
        BatteryAnalytics.dayMetrics(samples: samples)
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
