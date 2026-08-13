import Foundation
import SwiftData
import Testing
@testable import Voltline

struct HealthAnalyticsTests {
    @Test
    func healthPercentageRequiresBothCapacities() {
        #expect(HealthAnalytics.healthPercentage(fullChargeCapacity: 8_000, designCapacity: 10_000) == 80)
        #expect(HealthAnalytics.healthPercentage(fullChargeCapacity: nil, designCapacity: 10_000) == nil)
        #expect(HealthAnalytics.healthPercentage(fullChargeCapacity: 8_000, designCapacity: nil) == nil)
        #expect(HealthAnalytics.healthPercentage(fullChargeCapacity: 8_000, designCapacity: 0) == nil)
    }

    @Test
    func exposureAndEquivalentCyclesUseMeasuredIntervals() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let samples = [
            sample(at: start, level: 100, temperature: 36),
            sample(at: start.addingTimeInterval(300), level: 90, temperature: 36),
            sample(at: start.addingTimeInterval(600), level: 75, temperature: 34),
            sample(at: start.addingTimeInterval(900), level: 15, temperature: 34),
            sample(at: start.addingTimeInterval(1200), level: 50, temperature: 34)
        ]
        let result = HealthAnalytics.exposure(samples: samples)
        #expect(result.measuredDuration == 1_200)
        #expect(result.aboveEightyDuration == 600)
        #expect(result.belowTwentyDuration == 300)
        #expect(result.aboveThirtyFiveDuration == 600)
        #expect(result.atFullDuration == 300)
        #expect(result.recommendedRangeDuration == 300)
        #expect(abs((result.equivalentFullCycles ?? 0) - 0.85) < 0.0001)
    }

    @Test
    func missingTemperatureRemainsUnavailable() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let result = HealthAnalytics.exposure(samples: [
            sample(at: start, level: 70, temperature: nil),
            sample(at: start.addingTimeInterval(300), level: 69, temperature: nil)
        ])
        #expect(result.aboveThirtyFiveDuration == nil)
        #expect(result.recommendedRangeDuration == 300)
    }

    @Test
    func gapsAreNotCountedAsExposureOrCycles() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let result = HealthAnalytics.exposure(samples: [
            sample(at: start, level: 100, temperature: 40),
            sample(at: start.addingTimeInterval(3_600), level: 10, temperature: 20)
        ])
        #expect(result.measuredDuration == 0)
        #expect(result.equivalentFullCycles == nil)
    }

    @Test
    func dailyAggregationRespectsCalendarBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let first = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 59)) ?? .now
        let second = first.addingTimeInterval(120)
        let result = HealthAnalytics.dailyRepresentatives(samples: [
            sample(at: first, level: 60, temperature: 31),
            sample(at: second, level: 59, temperature: 32)
        ], calendar: calendar)
        #expect(result.count == 2)
        #expect(result[0].timestamp == first)
        #expect(result[1].timestamp == second)
    }

    @Test
    func dailyAggregationKeepsLatestMeasuredSample() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let result = HealthAnalytics.dailyRepresentatives(samples: [
            sample(at: start, level: 60, temperature: 30, fullCapacity: 8_200),
            sample(at: start.addingTimeInterval(300), level: 59, temperature: 31, fullCapacity: 8_190)
        ])
        #expect(result.count == 1)
        #expect(result[0].electrical.fullChargeCapacityMilliampHours == 8_190)
    }

    @Test
    func conservativeTrendRequiresSustainedPlausibleDecline() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshots = (0..<60).map { day in
            healthPoint(day: start.addingTimeInterval(Double(day) * 86_400), fullCapacity: 1_000 - Double(day))
        }
        let result = HealthAnalytics.capacityTrend(
            snapshots: snapshots,
            referenceDate: snapshots.last?.day ?? start
        )
        #expect(result != nil)
        #expect(abs((result?.monthlyCapacityChangeMilliampHours ?? 0) + 30.4375) < 0.001)
        #expect((result?.estimatedHealthInSixMonths ?? 0) < 80)
        #expect(result?.estimatedDateAtEightyPercent != nil)
    }

    @Test
    func trendRejectsSparseAndImprovingData() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let sparse = (0..<3).map { day in
            healthPoint(day: start.addingTimeInterval(Double(day) * 86_400), fullCapacity: 1_000 - Double(day))
        }
        let improving = (0..<30).map { day in
            healthPoint(day: start.addingTimeInterval(Double(day) * 86_400), fullCapacity: 900 + Double(day))
        }
        #expect(HealthAnalytics.capacityTrend(snapshots: sparse, referenceDate: start) == nil)
        #expect(HealthAnalytics.capacityTrend(snapshots: improving, referenceDate: start) == nil)
    }

    @Test
    func manufactureDateDecodingRejectsInvalidValues() {
        let encoded = UInt16((2024 - 1980) << 9 | 2 << 5 | 12)
        let date = BatteryHardwareService.manufactureDate(from: NSNumber(value: encoded))
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date ?? .distantPast)
        #expect(components.year == 2024)
        #expect(components.month == 2)
        #expect(components.day == 12)
        #expect(BatteryHardwareService.manufactureDate(from: NSNumber(value: UInt64.max)) == nil)
    }

    @Test @MainActor
    func dailyHealthSnapshotPersistsSeparately() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let container = try VoltlinePersistence.makeContainer(at: directory.appending(path: "health.store"))
        let context = ModelContext(container)
        let snapshot = batterySnapshot(at: Date(timeIntervalSince1970: 1_800_000_000))
        let day = Calendar.current.startOfDay(for: snapshot.timestamp)
        context.insert(DailyHealthSnapshotRecord(day: day, snapshot: snapshot))
        try context.save()

        let records = try context.fetch(FetchDescriptor<DailyHealthSnapshotRecord>())
        #expect(records.count == 1)
        #expect(records[0].fullChargeCapacityMilliampHours == 8_200)
        #expect(records[0].healthPercentage == 82)
        #expect(records[0].cycleCount == 120)
    }

    private func sample(
        at date: Date,
        level: Double,
        temperature: Double?,
        fullCapacity: Double = 8_200
    ) -> BatterySamplePoint {
        BatterySamplePoint(
            id: UUID(),
            timestamp: date,
            batteryLevel: level,
            powerSource: .battery,
            chargingState: .discharging,
            systemEstimate: .unavailable,
            lowPowerModeEnabled: false,
            displayActive: true,
            systemSleeping: false,
            sessionID: UUID(),
            electrical: electrical(temperature: temperature, fullCapacity: fullCapacity)
        )
    }

    private func healthPoint(day: Date, fullCapacity: Double) -> DailyHealthSnapshotPoint {
        DailyHealthSnapshotPoint(
            id: UUID(),
            day: day,
            capturedAt: day,
            fullChargeCapacityMilliampHours: fullCapacity,
            designCapacityMilliampHours: 1_000,
            healthPercentage: fullCapacity / 10,
            cycleCount: nil,
            temperatureCelsius: nil,
            hardwarePercentage: nil,
            condition: nil,
            manufactureDate: nil
        )
    }

    private func batterySnapshot(at date: Date) -> BatterySnapshot {
        BatterySnapshot(
            timestamp: date,
            percentage: 60,
            powerSource: .battery,
            chargingState: .discharging,
            systemTimeRemaining: .unavailable,
            timeUntilFull: .unavailable,
            lowPowerModeEnabled: false,
            displayActive: true,
            systemSleeping: false,
            warningState: .unavailable,
            electrical: electrical(temperature: 32, fullCapacity: 8_200)
        )
    }

    private func electrical(temperature: Double?, fullCapacity: Double) -> BatteryElectricalTelemetry {
        BatteryElectricalTelemetry(
            voltageVolts: 11.8,
            amperageAmps: -1.4,
            batteryPowerWatts: 16.5,
            adapterPowerWatts: nil,
            systemPowerWatts: 16.5,
            temperatureCelsius: temperature,
            currentCapacityMilliampHours: 4_900,
            fullChargeCapacityMilliampHours: fullCapacity,
            designCapacityMilliampHours: 10_000,
            cycleCount: 120,
            condition: "Normal",
            adapterCapacityWatts: nil,
            adapterIdentity: nil,
            connectionType: nil,
            hardwarePercentage: 59,
            manufactureDate: nil
        )
    }
}
