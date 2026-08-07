import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let hardware = BatteryHardwareService()

    var currentSnapshot: BatterySnapshot?
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
        } catch {
            lastError = error.localizedDescription
        }
    }
}
