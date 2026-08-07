import Foundation

enum PowerSource: String, Codable, Sendable, CaseIterable {
    case battery
    case external
    case unknown
}

enum ChargingState: String, Codable, Sendable {
    case charging
    case charged
    case discharging
    case connectedNotCharging
    case unknown
}

enum BatteryTimeEstimate: Codable, Sendable, Equatable {
    case estimated(seconds: TimeInterval)
    case calculating
    case unlimited
    case unavailable

    var seconds: TimeInterval? {
        if case let .estimated(seconds) = self {
            return seconds
        }
        return nil
    }
}

enum BatteryWarningState: String, Codable, Sendable {
    case none
    case low
    case critical
    case unavailable
}

struct BatterySnapshot: Sendable, Equatable {
    let timestamp: Date
    let percentage: Double
    let powerSource: PowerSource
    let chargingState: ChargingState
    let systemTimeRemaining: BatteryTimeEstimate
    let timeUntilFull: BatteryTimeEstimate
    let lowPowerModeEnabled: Bool
    let displayActive: Bool
    let systemSleeping: Bool
    let warningState: BatteryWarningState

    var isCharging: Bool {
        chargingState == .charging
    }

    var isConnectedToPower: Bool {
        powerSource == .external
    }
}

struct BatterySamplePoint: Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let batteryLevel: Double
    let powerSource: PowerSource
    let chargingState: ChargingState
    let systemEstimate: BatteryTimeEstimate
    let lowPowerModeEnabled: Bool
    let displayActive: Bool
    let systemSleeping: Bool
    let sessionID: UUID

    var isCharging: Bool {
        chargingState == .charging
    }
}

