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
                connectionType: nil
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
            connectionType: source == .external ? .usbC : nil
        )
    }

    static var accessories: [BatteryDevice] {
        [
            BatteryDevice(id: "sample|airpods|left", name: "AirPods Pro", component: "Left", kind: .headphones, level: 68, isCharging: false, lastSeen: .now),
            BatteryDevice(id: "sample|airpods|right", name: "AirPods Pro", component: "Right", kind: .headphones, level: 64, isCharging: false, lastSeen: .now),
            BatteryDevice(id: "sample|mouse|main", name: "Magic Mouse", component: nil, kind: .mouse, level: 41, isCharging: false, lastSeen: .now)
        ]
    }
}
