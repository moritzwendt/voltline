import Foundation

enum SampleData {
    static func workday(now: Date = .now) -> [BatterySamplePoint] {
        let session = UUID()
        return stride(from: 0, through: 24, by: 1).map { index in
            BatterySamplePoint(
                id: UUID(),
                timestamp: now.addingTimeInterval(Double(index - 24) * 900),
                batteryLevel: max(38, 92 - Double(index) * 2.2),
                powerSource: .battery,
                chargingState: .discharging,
                systemEstimate: .calculating,
                lowPowerModeEnabled: false,
                displayActive: true,
                systemSleeping: false,
                sessionID: session
            )
        }
    }
}

