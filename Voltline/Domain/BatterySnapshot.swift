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

enum PowerConnectionType: String, Codable, Sendable {
    case usbC
    case magsafe
    case wireless
    case other
}

enum BatteryPowerDirection: String, Codable, Sendable {
    case charging
    case discharging
    case idle
}

struct BatteryElectricalTelemetry: Sendable, Equatable {
    static let positiveBatteryPowerMeaning = BatteryPowerDirection.discharging
    static let negativeBatteryPowerMeaning = BatteryPowerDirection.charging

    let voltageVolts: Double?
    let amperageAmps: Double?
    let batteryPowerWatts: Double?
    let adapterPowerWatts: Double?
    let systemPowerWatts: Double?
    let temperatureCelsius: Double?
    let currentCapacityMilliampHours: Double?
    let fullChargeCapacityMilliampHours: Double?
    let designCapacityMilliampHours: Double?
    let cycleCount: Int?
    let condition: String?
    let adapterCapacityWatts: Double?
    let adapterIdentity: String?
    let connectionType: PowerConnectionType?

    var batteryPowerDirection: BatteryPowerDirection? {
        guard let batteryPowerWatts else {
            return nil
        }
        if batteryPowerWatts > 0 {
            return .discharging
        }
        if batteryPowerWatts < 0 {
            return .charging
        }
        return .idle
    }

    static let unavailable = BatteryElectricalTelemetry(
        voltageVolts: nil,
        amperageAmps: nil,
        batteryPowerWatts: nil,
        adapterPowerWatts: nil,
        systemPowerWatts: nil,
        temperatureCelsius: nil,
        currentCapacityMilliampHours: nil,
        fullChargeCapacityMilliampHours: nil,
        designCapacityMilliampHours: nil,
        cycleCount: nil,
        condition: nil,
        adapterCapacityWatts: nil,
        adapterIdentity: nil,
        connectionType: nil
    )
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
    let electrical: BatteryElectricalTelemetry

    init(
        timestamp: Date,
        percentage: Double,
        powerSource: PowerSource,
        chargingState: ChargingState,
        systemTimeRemaining: BatteryTimeEstimate,
        timeUntilFull: BatteryTimeEstimate,
        lowPowerModeEnabled: Bool,
        displayActive: Bool,
        systemSleeping: Bool,
        warningState: BatteryWarningState,
        electrical: BatteryElectricalTelemetry = .unavailable
    ) {
        self.timestamp = timestamp
        self.percentage = percentage
        self.powerSource = powerSource
        self.chargingState = chargingState
        self.systemTimeRemaining = systemTimeRemaining
        self.timeUntilFull = timeUntilFull
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.displayActive = displayActive
        self.systemSleeping = systemSleeping
        self.warningState = warningState
        self.electrical = electrical
    }

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
    let electrical: BatteryElectricalTelemetry

    init(
        id: UUID,
        timestamp: Date,
        batteryLevel: Double,
        powerSource: PowerSource,
        chargingState: ChargingState,
        systemEstimate: BatteryTimeEstimate,
        lowPowerModeEnabled: Bool,
        displayActive: Bool,
        systemSleeping: Bool,
        sessionID: UUID,
        electrical: BatteryElectricalTelemetry = .unavailable
    ) {
        self.id = id
        self.timestamp = timestamp
        self.batteryLevel = batteryLevel
        self.powerSource = powerSource
        self.chargingState = chargingState
        self.systemEstimate = systemEstimate
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.displayActive = displayActive
        self.systemSleeping = systemSleeping
        self.sessionID = sessionID
        self.electrical = electrical
    }

    var isCharging: Bool {
        chargingState == .charging
    }
}
