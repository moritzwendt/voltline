import Foundation
import SwiftData

@Model
final class BatterySampleRecord {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var batteryLevel: Double
    var powerSourceRaw: String
    var chargingStateRaw: String
    var estimateKindRaw: String
    var estimateSeconds: Double?
    var timeUntilFullSeconds: Double?
    var lowPowerModeEnabled: Bool
    var displayActive: Bool
    var systemSleeping: Bool
    var sessionID: UUID
    var voltageVolts: Double?
    var amperageAmps: Double?
    var batteryPowerWatts: Double?
    var adapterPowerWatts: Double?
    var systemPowerWatts: Double?
    var temperatureCelsius: Double?
    var currentCapacityMilliampHours: Double?
    var fullChargeCapacityMilliampHours: Double?
    var designCapacityMilliampHours: Double?
    var cycleCount: Int?
    var batteryCondition: String?
    var adapterCapacityWatts: Double?
    var adapterIdentity: String?
    var connectionTypeRaw: String?
    var hardwarePercentage: Double?
    var manufactureDate: Date?

    init(snapshot: BatterySnapshot, sessionID: UUID) {
        id = UUID()
        timestamp = snapshot.timestamp
        batteryLevel = snapshot.percentage
        powerSourceRaw = snapshot.powerSource.rawValue
        chargingStateRaw = snapshot.chargingState.rawValue
        let persistedEstimate = Self.persisted(snapshot.systemTimeRemaining)
        estimateKindRaw = persistedEstimate.kind
        estimateSeconds = persistedEstimate.seconds
        timeUntilFullSeconds = snapshot.timeUntilFull.seconds
        lowPowerModeEnabled = snapshot.lowPowerModeEnabled
        displayActive = snapshot.displayActive
        systemSleeping = snapshot.systemSleeping
        self.sessionID = sessionID
        voltageVolts = snapshot.electrical.voltageVolts
        amperageAmps = snapshot.electrical.amperageAmps
        batteryPowerWatts = snapshot.electrical.batteryPowerWatts
        adapterPowerWatts = snapshot.electrical.adapterPowerWatts
        systemPowerWatts = snapshot.electrical.systemPowerWatts
        temperatureCelsius = snapshot.electrical.temperatureCelsius
        currentCapacityMilliampHours = snapshot.electrical.currentCapacityMilliampHours
        fullChargeCapacityMilliampHours = snapshot.electrical.fullChargeCapacityMilliampHours
        designCapacityMilliampHours = snapshot.electrical.designCapacityMilliampHours
        cycleCount = snapshot.electrical.cycleCount
        batteryCondition = snapshot.electrical.condition
        adapterCapacityWatts = snapshot.electrical.adapterCapacityWatts
        adapterIdentity = snapshot.electrical.adapterIdentity
        connectionTypeRaw = snapshot.electrical.connectionType?.rawValue
        hardwarePercentage = snapshot.electrical.hardwarePercentage
        manufactureDate = snapshot.electrical.manufactureDate
    }

    init(copying record: BatterySampleRecord) {
        id = record.id
        timestamp = record.timestamp
        batteryLevel = record.batteryLevel
        powerSourceRaw = record.powerSourceRaw
        chargingStateRaw = record.chargingStateRaw
        estimateKindRaw = record.estimateKindRaw
        estimateSeconds = record.estimateSeconds
        timeUntilFullSeconds = record.timeUntilFullSeconds
        lowPowerModeEnabled = record.lowPowerModeEnabled
        displayActive = record.displayActive
        systemSleeping = record.systemSleeping
        sessionID = record.sessionID
        voltageVolts = record.voltageVolts
        amperageAmps = record.amperageAmps
        batteryPowerWatts = record.batteryPowerWatts
        adapterPowerWatts = record.adapterPowerWatts
        systemPowerWatts = record.systemPowerWatts
        temperatureCelsius = record.temperatureCelsius
        currentCapacityMilliampHours = record.currentCapacityMilliampHours
        fullChargeCapacityMilliampHours = record.fullChargeCapacityMilliampHours
        designCapacityMilliampHours = record.designCapacityMilliampHours
        cycleCount = record.cycleCount
        batteryCondition = record.batteryCondition
        adapterCapacityWatts = record.adapterCapacityWatts
        adapterIdentity = record.adapterIdentity
        connectionTypeRaw = record.connectionTypeRaw
        hardwarePercentage = record.hardwarePercentage
        manufactureDate = record.manufactureDate
    }

    var point: BatterySamplePoint {
        BatterySamplePoint(
            id: id,
            timestamp: timestamp,
            batteryLevel: batteryLevel,
            powerSource: PowerSource(rawValue: powerSourceRaw) ?? .unknown,
            chargingState: ChargingState(rawValue: chargingStateRaw) ?? .unknown,
            systemEstimate: Self.restored(kind: estimateKindRaw, seconds: estimateSeconds),
            lowPowerModeEnabled: lowPowerModeEnabled,
            displayActive: displayActive,
            systemSleeping: systemSleeping,
            sessionID: sessionID,
            electrical: BatteryElectricalTelemetry(
                voltageVolts: voltageVolts,
                amperageAmps: amperageAmps,
                batteryPowerWatts: batteryPowerWatts,
                adapterPowerWatts: adapterPowerWatts,
                systemPowerWatts: systemPowerWatts,
                temperatureCelsius: temperatureCelsius,
                currentCapacityMilliampHours: currentCapacityMilliampHours,
                fullChargeCapacityMilliampHours: fullChargeCapacityMilliampHours,
                designCapacityMilliampHours: designCapacityMilliampHours,
                cycleCount: cycleCount,
                condition: batteryCondition,
                adapterCapacityWatts: adapterCapacityWatts,
                adapterIdentity: adapterIdentity,
                connectionType: connectionTypeRaw.flatMap(PowerConnectionType.init(rawValue:)),
                hardwarePercentage: hardwarePercentage,
                manufactureDate: manufactureDate
            )
        )
    }

    private static func persisted(_ estimate: BatteryTimeEstimate) -> (kind: String, seconds: Double?) {
        switch estimate {
        case let .estimated(seconds): ("estimated", seconds)
        case .calculating: ("calculating", nil)
        case .unlimited: ("unlimited", nil)
        case .unavailable: ("unavailable", nil)
        }
    }

    private static func restored(kind: String, seconds: Double?) -> BatteryTimeEstimate {
        switch kind {
        case "estimated": .estimated(seconds: seconds ?? 0)
        case "calculating": .calculating
        case "unlimited": .unlimited
        default: .unavailable
        }
    }
}

struct DailyHealthSnapshotPoint: Identifiable, Sendable, Equatable {
    let id: UUID
    let day: Date
    let capturedAt: Date
    let fullChargeCapacityMilliampHours: Double?
    let designCapacityMilliampHours: Double?
    let healthPercentage: Double?
    let cycleCount: Int?
    let temperatureCelsius: Double?
    let hardwarePercentage: Double?
    let condition: String?
    let manufactureDate: Date?
}

@Model
final class DailyHealthSnapshotRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var day: Date
    var capturedAt: Date
    var fullChargeCapacityMilliampHours: Double?
    var designCapacityMilliampHours: Double?
    var healthPercentage: Double?
    var cycleCount: Int?
    var temperatureCelsius: Double?
    var hardwarePercentage: Double?
    var condition: String?
    var manufactureDate: Date?

    init(day: Date, snapshot: BatterySnapshot) {
        id = UUID()
        self.day = day
        capturedAt = snapshot.timestamp
        apply(snapshot)
    }

    init(day: Date, sample: BatterySamplePoint) {
        id = UUID()
        self.day = day
        capturedAt = sample.timestamp
        apply(sample)
    }

    init(copying record: DailyHealthSnapshotRecord) {
        id = record.id
        day = record.day
        capturedAt = record.capturedAt
        fullChargeCapacityMilliampHours = record.fullChargeCapacityMilliampHours
        designCapacityMilliampHours = record.designCapacityMilliampHours
        healthPercentage = record.healthPercentage
        cycleCount = record.cycleCount
        temperatureCelsius = record.temperatureCelsius
        hardwarePercentage = record.hardwarePercentage
        condition = record.condition
        manufactureDate = record.manufactureDate
    }

    func apply(_ snapshot: BatterySnapshot) {
        capturedAt = snapshot.timestamp
        fullChargeCapacityMilliampHours = snapshot.electrical.fullChargeCapacityMilliampHours
        designCapacityMilliampHours = snapshot.electrical.designCapacityMilliampHours
        healthPercentage = HealthAnalytics.healthPercentage(
            fullChargeCapacity: snapshot.electrical.fullChargeCapacityMilliampHours,
            designCapacity: snapshot.electrical.designCapacityMilliampHours
        )
        cycleCount = snapshot.electrical.cycleCount
        temperatureCelsius = snapshot.electrical.temperatureCelsius
        hardwarePercentage = snapshot.electrical.hardwarePercentage
        condition = snapshot.electrical.condition
        manufactureDate = snapshot.electrical.manufactureDate
    }

    func apply(_ sample: BatterySamplePoint) {
        capturedAt = sample.timestamp
        fullChargeCapacityMilliampHours = sample.electrical.fullChargeCapacityMilliampHours
        designCapacityMilliampHours = sample.electrical.designCapacityMilliampHours
        healthPercentage = HealthAnalytics.healthPercentage(
            fullChargeCapacity: sample.electrical.fullChargeCapacityMilliampHours,
            designCapacity: sample.electrical.designCapacityMilliampHours
        )
        cycleCount = sample.electrical.cycleCount
        temperatureCelsius = sample.electrical.temperatureCelsius
        hardwarePercentage = sample.electrical.hardwarePercentage
        condition = sample.electrical.condition
        manufactureDate = sample.electrical.manufactureDate
    }

    var point: DailyHealthSnapshotPoint {
        DailyHealthSnapshotPoint(
            id: id,
            day: day,
            capturedAt: capturedAt,
            fullChargeCapacityMilliampHours: fullChargeCapacityMilliampHours,
            designCapacityMilliampHours: designCapacityMilliampHours,
            healthPercentage: healthPercentage,
            cycleCount: cycleCount,
            temperatureCelsius: temperatureCelsius,
            hardwarePercentage: hardwarePercentage,
            condition: condition,
            manufactureDate: manufactureDate
        )
    }
}

@Model
final class PowerSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var categoryRaw: String
    var startingLevel: Double
    var endingLevel: Double

    init(id: UUID, startedAt: Date, category: PowerSource, startingLevel: Double) {
        self.id = id
        self.startedAt = startedAt
        categoryRaw = category.rawValue
        self.startingLevel = startingLevel
        endingLevel = startingLevel
    }

    init(copying record: PowerSessionRecord) {
        id = record.id
        startedAt = record.startedAt
        endedAt = record.endedAt
        categoryRaw = record.categoryRaw
        startingLevel = record.startingLevel
        endingLevel = record.endingLevel
    }
}

@Model
final class DailySummaryRecord {
    @Attribute(.unique) var day: Date
    var batteryConsumed: Double
    var activeBatteryTime: TimeInterval
    var averageDrainRate: Double
    var chargingTime: TimeInterval
    var dischargeSessions: Int

    init(day: Date) {
        self.day = day
        batteryConsumed = 0
        activeBatteryTime = 0
        averageDrainRate = 0
        chargingTime = 0
        dischargeSessions = 0
    }

    init(copying record: DailySummaryRecord) {
        day = record.day
        batteryConsumed = record.batteryConsumed
        activeBatteryTime = record.activeBatteryTime
        averageDrainRate = record.averageDrainRate
        chargingTime = record.chargingTime
        dischargeSessions = record.dischargeSessions
    }
}
