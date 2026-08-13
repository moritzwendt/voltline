import Foundation
import Testing
@testable import Voltline

struct PowerAnalyticsTests {
    @Test
    func rangeIncludesBoundaryMeasurementsInTimeOrder() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let samples = [
            point(at: start.addingTimeInterval(120), systemPower: 12),
            point(at: start, systemPower: 10),
            point(at: start.addingTimeInterval(60), systemPower: 11),
            point(at: start.addingTimeInterval(180), systemPower: 13)
        ]
        let result = PowerAnalytics.samples(
            samples,
            from: start.addingTimeInterval(60),
            through: start.addingTimeInterval(120)
        )
        #expect(result.count == 2)
        #expect(result.map(\.electrical.systemPowerWatts) == [11, 12])
    }

    @Test
    func metricSelectionExcludesOnlyUnavailableValues() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let measured = point(at: start, systemPower: 15)
        let unavailable = point(at: start.addingTimeInterval(60), systemPower: nil)
        let result = PowerAnalytics.measuredSamples([measured, unavailable], metric: .systemPower)
        #expect(result.map(\.id) == [measured.id])
    }

    @Test
    func graphInspectionUsesOriginalMeasurementAfterDisplayReduction() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let samples = (0..<20).map { index in
            point(at: start.addingTimeInterval(Double(index * 60)), systemPower: Double(index))
        }
        let display = PowerAnalytics.displaySamples(samples, metric: .systemPower, maxPoints: 5)
        let target = samples[7]
        let inspected = PowerAnalytics.nearestOriginalSample(to: target.timestamp, in: samples, metric: .systemPower)
        #expect(display.count < samples.count)
        #expect(!display.contains(where: { $0.id == target.id }))
        #expect(inspected?.id == target.id)
        #expect(inspected?.electrical.systemPowerWatts == 7)
    }

    @Test
    func everyGraphMetricReadsItsStoredMeasurement() {
        let sample = point(at: .now, systemPower: 21)
        #expect(PowerGraphMetric.systemPower.value(in: sample) == 21)
        #expect(PowerGraphMetric.adapterPower.value(in: sample) == 35)
        #expect(PowerGraphMetric.batteryPower.value(in: sample) == -14)
        #expect(PowerGraphMetric.voltage.value(in: sample) == 11.8)
        #expect(PowerGraphMetric.current.value(in: sample) == 1.2)
        #expect(PowerGraphMetric.temperature.value(in: sample) == 32.5)
    }

    private func point(at date: Date, systemPower: Double?) -> BatterySamplePoint {
        BatterySamplePoint(
            id: UUID(),
            timestamp: date,
            batteryLevel: 60,
            powerSource: .external,
            chargingState: .charging,
            systemEstimate: .unavailable,
            lowPowerModeEnabled: false,
            displayActive: true,
            systemSleeping: false,
            sessionID: UUID(),
            electrical: BatteryElectricalTelemetry(
                voltageVolts: 11.8,
                amperageAmps: 1.2,
                batteryPowerWatts: -14,
                adapterPowerWatts: 35,
                systemPowerWatts: systemPower,
                temperatureCelsius: 32.5,
                currentCapacityMilliampHours: 4_944,
                fullChargeCapacityMilliampHours: 8_240,
                designCapacityMilliampHours: 8_579,
                cycleCount: 50,
                condition: "Normal",
                adapterCapacityWatts: 35,
                adapterIdentity: "35W USB C Power Adapter",
                connectionType: .usbC
            )
        )
    }
}
