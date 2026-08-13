import Foundation
import SwiftData
import Testing
@testable import Voltline

struct ElectricalTelemetryTests {
    @Test
    func convertsMillivoltsAndMilliampsToWatts() {
        let watts = BatteryHardwareService.power(voltageMillivolts: 12_000, amperageMilliamps: 1_500)
        #expect(watts == 18)
    }

    @Test
    func chargingPowerIsNegative() {
        let telemetry = BatteryHardwareService.electricalTelemetry(
            powerSourceDescription: [:],
            batteryProperties: [
                "Voltage": 12_000,
                "Amperage": 1_500
            ],
            packProperties: [:],
            adapterDetails: nil,
            powerSource: .external,
            chargingState: .charging
        )
        #expect(telemetry.batteryPowerWatts == -18)
        #expect(telemetry.batteryPowerDirection == .charging)
        #expect(BatteryElectricalTelemetry.negativeBatteryPowerMeaning == .charging)
    }

    @Test
    func dischargingPowerIsPositive() {
        let telemetry = BatteryHardwareService.electricalTelemetry(
            powerSourceDescription: [:],
            batteryProperties: [
                "PowerTelemetryData": ["BatteryPower": -22_500]
            ],
            packProperties: [:],
            adapterDetails: nil,
            powerSource: .battery,
            chargingState: .discharging
        )
        #expect(telemetry.batteryPowerWatts == 22.5)
        #expect(telemetry.batteryPowerDirection == .discharging)
        #expect(BatteryElectricalTelemetry.positiveBatteryPowerMeaning == .discharging)
    }

    @Test
    func wrappedSignedRegistryValuesPreserveDischargeDirection() {
        let wrappedPower = UInt64(bitPattern: Int64(-22_500))
        let wrappedCurrent = UInt64(bitPattern: Int64(-1_900))
        let telemetry = BatteryHardwareService.electricalTelemetry(
            powerSourceDescription: [:],
            batteryProperties: [
                "Voltage": 11_800,
                "InstantAmperage": wrappedCurrent,
                "PowerTelemetryData": ["BatteryPower": wrappedPower]
            ],
            packProperties: [:],
            adapterDetails: nil,
            powerSource: .external,
            chargingState: .charging
        )
        #expect(telemetry.amperageAmps == -1.9)
        #expect(telemetry.batteryPowerWatts == 22.5)
        #expect(telemetry.batteryPowerDirection == .discharging)
    }

    @Test
    func missingMeasurementsRemainUnavailable() {
        let telemetry = BatteryHardwareService.electricalTelemetry(
            powerSourceDescription: [:],
            batteryProperties: [:],
            packProperties: [:],
            adapterDetails: nil,
            powerSource: .unknown,
            chargingState: .unknown
        )
        #expect(telemetry == .unavailable)
        #expect(telemetry.batteryPowerDirection == nil)
    }

    @Test
    func convertsBatteryTemperature() {
        #expect(BatteryHardwareService.temperatureCelsius(rawValue: 3_539) == 35.39)
        #expect(BatteryHardwareService.temperatureCelsius(rawValue: 0) == nil)
    }

    @Test @MainActor
    func persistsElectricalTelemetryAndUnavailableValues() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let container = try VoltlinePersistence.makeContainer(at: directory.appending(path: "telemetry.store"))
        let context = ModelContext(container)
        let electrical = BatteryElectricalTelemetry(
            voltageVolts: 11.8,
            amperageAmps: 1.4,
            batteryPowerWatts: -16.52,
            adapterPowerWatts: 35,
            systemPowerWatts: 18.48,
            temperatureCelsius: 33.2,
            currentCapacityMilliampHours: 4_120,
            fullChargeCapacityMilliampHours: 8_240,
            designCapacityMilliampHours: 8_579,
            cycleCount: 48,
            condition: "Normal",
            adapterCapacityWatts: 35,
            adapterIdentity: "35W USB C Power Adapter",
            connectionType: .usbC
        )
        let stored = BatterySampleRecord(snapshot: snapshot(electrical: electrical), sessionID: UUID())
        let unavailable = BatterySampleRecord(snapshot: snapshot(electrical: .unavailable), sessionID: UUID())
        context.insert(stored)
        context.insert(unavailable)
        try context.save()

        let records = try context.fetch(FetchDescriptor<BatterySampleRecord>())
        #expect(records.count == 2)
        #expect(records.first(where: { $0.id == stored.id })?.point.electrical == electrical)
        #expect(records.first(where: { $0.id == unavailable.id })?.point.electrical == .unavailable)
    }

    private func snapshot(electrical: BatteryElectricalTelemetry) -> BatterySnapshot {
        BatterySnapshot(
            timestamp: .now,
            percentage: 50,
            powerSource: .external,
            chargingState: .charging,
            systemTimeRemaining: .unlimited,
            timeUntilFull: .calculating,
            lowPowerModeEnabled: false,
            displayActive: true,
            systemSleeping: false,
            warningState: .unavailable,
            electrical: electrical
        )
    }
}
