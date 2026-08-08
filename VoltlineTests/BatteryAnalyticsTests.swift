import Foundation
import Testing
@testable import Voltline

struct BatteryAnalyticsTests {
    @Test
    func constantDischargeIsTenPercentPerHour() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let samples = [
            point(at: start, level: 100),
            point(at: start.addingTimeInterval(3600), level: 90),
            point(at: start.addingTimeInterval(7200), level: 80)
        ]
        let rate = BatteryAnalytics.dischargeRate(samples: samples, window: 10_800)
        #expect(abs((rate ?? 0) + 10) < 0.001)
    }

    @Test
    func chargingDoesNotCountAsDischarge() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let dischargeOne = UUID()
        let charging = UUID()
        let dischargeTwo = UUID()
        let samples = [
            point(at: start, level: 80, session: dischargeOne),
            point(at: start.addingTimeInterval(300), level: 60, session: dischargeOne),
            point(at: start.addingTimeInterval(600), level: 60, source: .external, state: .charging, session: charging),
            point(at: start.addingTimeInterval(900), level: 90, source: .external, state: .charging, session: charging),
            point(at: start.addingTimeInterval(1200), level: 90, session: dischargeTwo),
            point(at: start.addingTimeInterval(1500), level: 70, session: dischargeTwo)
        ]
        let metrics = BatteryAnalytics.dayMetrics(samples: samples)
        #expect(metrics.batteryUsed == 40)
        #expect(metrics.chargingTime == 300)
    }

    @Test
    func sleepGapDoesNotCorruptActiveDrain() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = UUID()
        let samples = [
            point(at: start, level: 90, session: session),
            point(at: start.addingTimeInterval(300), level: 89, session: session),
            point(at: start.addingTimeInterval(3600), level: 86, sleeping: true, session: session),
            point(at: start.addingTimeInterval(3900), level: 85, session: session)
        ]
        let metrics = BatteryAnalytics.dayMetrics(samples: samples)
        #expect(metrics.batteryUsed == 1)
        #expect(metrics.timeOnBattery == 300)
    }

    @Test
    func regressionSmoothsNoisyPercentageUpdates() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let levels = [100.0, 100, 99, 99, 98, 98, 97]
        let samples = levels.enumerated().map { index, level in
            point(at: start.addingTimeInterval(Double(index * 600)), level: level)
        }
        let rate = BatteryAnalytics.dischargeRate(samples: samples, window: 7200)
        #expect(rate != nil)
        #expect((rate ?? 0) < 0)
        #expect((rate ?? 0) > -5)
    }

    @Test
    func unavailableEstimateHasNoSeconds() {
        #expect(BatteryTimeEstimate.unavailable.seconds == nil)
        #expect(BatteryTimeEstimate.calculating.seconds == nil)
        #expect(BatteryTimeEstimate.unlimited.seconds == nil)
    }

    @Test
    func sessionCanCrossMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 23, minute: 55)) ?? .now
        let session = UUID()
        let samples = [
            point(at: start, level: 80, session: session),
            point(at: start.addingTimeInterval(600), level: 78, session: session)
        ]
        let metrics = BatteryAnalytics.dayMetrics(samples: samples)
        #expect(metrics.batteryUsed == 2)
        #expect(metrics.sessionCount == 1)
    }

    private func point(
        at date: Date,
        level: Double,
        source: PowerSource = .battery,
        state: ChargingState = .discharging,
        sleeping: Bool = false,
        session: UUID = UUID(uuidString: "6424BA24-A5F0-43B2-A98C-3E44CFDF52D6") ?? UUID()
    ) -> BatterySamplePoint {
        BatterySamplePoint(
            id: UUID(),
            timestamp: date,
            batteryLevel: level,
            powerSource: source,
            chargingState: state,
            systemEstimate: .unavailable,
            lowPowerModeEnabled: false,
            displayActive: !sleeping,
            systemSleeping: sleeping,
            sessionID: session
        )
    }
}
