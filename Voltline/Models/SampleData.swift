import Foundation

enum SampleData {
    static func typicalWorkday(day: Date = .now, calendar: Calendar = .current) -> [BatterySamplePoint] {
        let start = calendar.date(bySettingHour: 8, minute: 10, second: 0, of: day) ?? day
        let firstSession = UUID(uuidString: "13B8523F-1765-44ED-BFD9-8B4707B440F1") ?? UUID()
        let chargingSession = UUID(uuidString: "894BB2E0-C1C2-48D6-97C8-7D6C782AAE3B") ?? UUID()
        let secondSession = UUID(uuidString: "D974BCE6-4DE3-4CA1-A0C5-750580C7A736") ?? UUID()
        var points: [BatterySamplePoint] = []

        for minute in stride(from: 0, through: 600, by: 5) {
            let date = start.addingTimeInterval(Double(minute * 60))
            let breakPeriod = minute >= 205 && minute <= 250
            let charging = minute >= 330 && minute <= 390
            let secondDischarge = minute > 390
            let level: Double
            let source: PowerSource
            let state: ChargingState
            let session: UUID

            if charging {
                level = min(82, 59 + Double(minute - 330) * 0.38)
                source = .external
                state = .charging
                session = chargingSession
            } else if secondDischarge {
                level = max(43, 82 - Double(minute - 390) * 0.17)
                source = .battery
                state = .discharging
                session = secondSession
            } else {
                level = max(59, 98 - Double(minute) * 0.118)
                source = .battery
                state = .discharging
                session = firstSession
            }

            points.append(BatterySamplePoint(
                id: UUID(),
                timestamp: date,
                batteryLevel: level,
                powerSource: source,
                chargingState: state,
                systemEstimate: source == .battery ? .estimated(seconds: level / 8.7 * 3600) : .unlimited,
                lowPowerModeEnabled: minute >= 510,
                displayActive: !breakPeriod,
                systemSleeping: false,
                sessionID: session,
                electrical: telemetry(source: source, state: state, minute: minute, level: level)
            ))
        }
        return points
    }

    static var currentSnapshot: BatterySnapshot {
        BatterySnapshot(
            timestamp: .now,
            percentage: 47,
            powerSource: .battery,
            chargingState: .discharging,
            systemTimeRemaining: .calculating,
            timeUntilFull: .unavailable,
            lowPowerModeEnabled: false,
            displayActive: true,
            systemSleeping: false,
            warningState: .unavailable,
            electrical: BatteryElectricalTelemetry(
                voltageVolts: 11.62,
                amperageAmps: -1.74,
                batteryPowerWatts: 20.22,
                adapterPowerWatts: nil,
                systemPowerWatts: 20.22,
                temperatureCelsius: 31.4,
                currentCapacityMilliampHours: 3_980,
                fullChargeCapacityMilliampHours: 8_240,
                designCapacityMilliampHours: 8_579,
                cycleCount: 48,
                condition: "Normal",
                adapterCapacityWatts: nil,
                adapterIdentity: nil,
                connectionType: nil,
                hardwarePercentage: 46,
                manufactureDate: Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 12))
            )
        )
    }

    private static func telemetry(source: PowerSource, state: ChargingState, minute: Int, level: Double) -> BatteryElectricalTelemetry {
        let voltage = 11.4 + level / 100 * 1.3
        let magnitude = 9.5 + Double(minute % 55) / 8
        let batteryPower = state == .charging ? 0 - magnitude : magnitude
        return BatteryElectricalTelemetry(
            voltageVolts: voltage,
            amperageAmps: batteryPower / voltage,
            batteryPowerWatts: batteryPower,
            adapterPowerWatts: source == .external ? 35 : nil,
            systemPowerWatts: source == .external ? 20 : magnitude,
            temperatureCelsius: 29 + Double(minute % 90) / 18,
            currentCapacityMilliampHours: 8_240 * level / 100,
            fullChargeCapacityMilliampHours: 8_240,
            designCapacityMilliampHours: 8_579,
            cycleCount: 48,
            condition: "Normal",
            adapterCapacityWatts: source == .external ? 35 : nil,
            adapterIdentity: source == .external ? "35W USB C Power Adapter" : nil,
            connectionType: source == .external ? .usbC : nil,
            hardwarePercentage: max(0, level - 1),
            manufactureDate: calendarDate(year: 2024, month: 2, day: 12)
        )
    }

    static func healthHistory(referenceDate: Date, calendar: Calendar = .current) -> [DailyHealthSnapshotPoint] {
        let end = calendar.startOfDay(for: referenceDate)
        return (0...400).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 400, to: end) else {
                return nil
            }
            let progress = Double(offset)
            let fullCapacity = 8_460 - progress * 0.55 + sin(progress / 17) * 9
            let designCapacity = 8_579.0
            return DailyHealthSnapshotPoint(
                id: UUID(),
                day: day,
                capturedAt: day.addingTimeInterval(12 * 60 * 60),
                fullChargeCapacityMilliampHours: fullCapacity,
                designCapacityMilliampHours: designCapacity,
                healthPercentage: fullCapacity / designCapacity * 100,
                cycleCount: 20 + Int(progress * 0.07),
                temperatureCelsius: 30 + sin(progress / 11) * 3.2,
                hardwarePercentage: 46,
                condition: "Normal",
                manufactureDate: calendarDate(year: 2024, month: 2, day: 12)
            )
        }
    }

    private static func calendarDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    static var accessories: [BatteryDevice] {
        [
            BatteryDevice(id: "sample|airpods|left", name: "AirPods Pro", component: "Left", kind: .headphones, level: 68, isCharging: false, lastSeen: .now),
            BatteryDevice(id: "sample|airpods|right", name: "AirPods Pro", component: "Right", kind: .headphones, level: 64, isCharging: false, lastSeen: .now),
            BatteryDevice(id: "sample|mouse|main", name: "Magic Mouse", component: nil, kind: .mouse, level: 41, isCharging: false, lastSeen: .now)
        ]
    }
}
