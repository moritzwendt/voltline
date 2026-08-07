import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let hardware = BatteryHardwareService()
    private let sessionID = UUID()

    var currentSnapshot: BatterySnapshot?
    var samples: [BatterySamplePoint] = []
    var lastUpdated: Date?
    var lastError: String?

    init() {
        refresh()
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
        } catch {
            lastError = error.localizedDescription
        }
    }
}
