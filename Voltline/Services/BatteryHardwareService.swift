import CoreGraphics
import Foundation
import IOKit
import IOKit.ps

struct BatteryHardwareService: Sendable {
    enum ServiceError: Error {
        case powerSourceUnavailable
        case batteryUnavailable
        case capacityUnavailable
    }

    func readSnapshot(systemSleeping: Bool = false) throws -> BatterySnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            throw ServiceError.powerSourceUnavailable
        }
        let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
        guard let description = sources.compactMap({ source in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }).first(where: { dictionary in
            (dictionary[kIOPSTypeKey as String] as? String) == kIOPSInternalBatteryType
        }) else {
            throw ServiceError.batteryUnavailable
        }

        guard let current = Self.number(description, key: kIOPSCurrentCapacityKey as String),
              let maximum = Self.number(description, key: kIOPSMaxCapacityKey as String),
              maximum > 0 else {
            throw ServiceError.capacityUnavailable
        }
        let percentage = min(max(current / maximum * 100, 0), 100)
        let sourceValue = description[kIOPSPowerSourceStateKey as String] as? String
        let powerSource: PowerSource = switch sourceValue {
        case kIOPSBatteryPowerValue: .battery
        case kIOPSACPowerValue: .external
        default: .unknown
        }
        let charging = description[kIOPSIsChargingKey as String] as? Bool ?? false
        let charged = description[kIOPSIsChargedKey as String] as? Bool ?? false
        let chargingState: ChargingState = if charging {
            .charging
        } else if charged {
            .charged
        } else if powerSource == .battery {
            .discharging
        } else if powerSource == .external {
            .connectedNotCharging
        } else {
            .unknown
        }

        let batteryProperties = registryProperties(className: "AppleSmartBattery")
        let packProperties = registryProperties(className: "AppleSmartBatteryPack")
        let adapterDetails = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        let electrical = Self.electricalTelemetry(
            powerSourceDescription: description,
            batteryProperties: batteryProperties,
            packProperties: packProperties,
            adapterDetails: adapterDetails,
            powerSource: powerSource,
            chargingState: chargingState
        )

        let mainDisplay = CGMainDisplayID()
        let displayActive = !systemSleeping && CGDisplayIsActive(mainDisplay) != 0 && CGDisplayIsAsleep(mainDisplay) == 0

        return BatterySnapshot(
            timestamp: .now,
            percentage: percentage,
            powerSource: powerSource,
            chargingState: chargingState,
            systemTimeRemaining: timeEstimate(IOPSGetTimeRemainingEstimate(), unknownMeansCalculating: powerSource == .battery),
            timeUntilFull: chargeTimeEstimate(description, isCharging: charging),
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            displayActive: displayActive,
            systemSleeping: systemSleeping,
            warningState: .unavailable,
            electrical: electrical
        )
    }

    static func electricalTelemetry(
        powerSourceDescription: [String: Any],
        batteryProperties: [String: Any],
        packProperties: [String: Any],
        adapterDetails: [String: Any]?,
        powerSource: PowerSource,
        chargingState: ChargingState
    ) -> BatteryElectricalTelemetry {
        let rootBatteryData = dictionary(batteryProperties, key: "BatteryData")
        let packBatteryData = dictionary(packProperties, key: "BatteryData")
        let powerData = dictionary(batteryProperties, key: "PowerTelemetryData")
        let registryAdapter = dictionary(batteryProperties, key: "AdapterDetails")
        let activeAdapter = powerSource == .external ? adapterDetails ?? registryAdapter : nil
        let voltageMillivolts = firstNumber(
            (batteryProperties, "Voltage"),
            (batteryProperties, "AppleRawBatteryVoltage"),
            (packBatteryData, "Voltage"),
            (packBatteryData, "AppleRawBatteryVoltage")
        )
        let amperageMilliamps = firstSignedNumber(
            (batteryProperties, "InstantAmperage"),
            (batteryProperties, "Amperage"),
            (packBatteryData, "InstantAmperage"),
            (packBatteryData, "Amperage")
        )
        let rawBatteryPower = firstSignedNumber(
            (powerData, "BatteryPower"),
            (rootBatteryData, "BatteryPower")
        )
        let signedBatteryPower = rawBatteryPower.map { 0 - $0 / 1_000 } ?? power(
            voltageMillivolts: voltageMillivolts,
            amperageMilliamps: amperageMilliamps
        ).map { magnitude in
            guard let amperageMilliamps else {
                return magnitude
            }
            return amperageMilliamps >= 0 ? 0 - magnitude : magnitude
        }
        let condition = firstString(
            (powerSourceDescription, "BatteryHealthCondition"),
            (powerSourceDescription, "BatteryHealth"),
            (batteryProperties, "BatteryHealthCondition"),
            (batteryProperties, "BatteryHealth")
        )

        return BatteryElectricalTelemetry(
            voltageVolts: voltageMillivolts.map { $0 / 1_000 },
            amperageAmps: amperageMilliamps.map { $0 / 1_000 },
            batteryPowerWatts: signedBatteryPower,
            adapterPowerWatts: number(powerData, key: "SystemPowerIn").map { $0 / 1_000 },
            systemPowerWatts: number(powerData, key: "SystemLoad").map { $0 / 1_000 },
            temperatureCelsius: firstNumber(
                (packBatteryData, "Temperature"),
                (packBatteryData, "VirtualTemperature"),
                (rootBatteryData, "Temperature"),
                (batteryProperties, "Temperature")
            ).flatMap(temperatureCelsius),
            currentCapacityMilliampHours: firstNumber(
                (rootBatteryData, "RemainingCapacity"),
                (packBatteryData, "AppleRawCurrentCapacity")
            ),
            fullChargeCapacityMilliampHours: firstNumber(
                (rootBatteryData, "FullChargeCapacity"),
                (packBatteryData, "AppleRawMaxCapacity"),
                (packBatteryData, "FccComp1")
            ),
            designCapacityMilliampHours: firstNumber(
                (rootBatteryData, "DesignCapacity"),
                (packBatteryData, "DesignCapacity")
            ),
            cycleCount: firstNumber(
                (batteryProperties, "CycleCount"),
                (packBatteryData, "CycleCount")
            ).map { Int($0) },
            condition: condition,
            adapterCapacityWatts: activeAdapter.flatMap { number($0, key: "Watts") },
            adapterIdentity: activeAdapter.flatMap(adapterIdentity),
            connectionType: activeAdapter.flatMap(connectionType)
        )
    }

    static func power(voltageMillivolts: Double?, amperageMilliamps: Double?) -> Double? {
        guard let voltageMillivolts, let amperageMilliamps else {
            return nil
        }
        return abs(voltageMillivolts * amperageMilliamps) / 1_000_000
    }

    static func temperatureCelsius(rawValue: Double) -> Double? {
        guard rawValue > 0 else {
            return nil
        }
        let value = rawValue >= 2_000 ? rawValue / 100 : rawValue
        return (-40...125).contains(value) ? value : nil
    }

    private func registryProperties(className: String) -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(className))
        guard service != 0 else {
            return [:]
        }
        defer {
            IOObjectRelease(service)
        }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
            return [:]
        }
        return properties?.takeRetainedValue() as? [String: Any] ?? [:]
    }

    private static func number(_ dictionary: [String: Any], key: String) -> Double? {
        (dictionary[key] as? NSNumber)?.doubleValue
    }

    private static func dictionary(_ dictionary: [String: Any], key: String) -> [String: Any] {
        dictionary[key] as? [String: Any] ?? [:]
    }

    private static func firstNumber(_ values: ([String: Any], String)...) -> Double? {
        values.lazy.compactMap { number($0.0, key: $0.1) }.first
    }

    private static func firstSignedNumber(_ values: ([String: Any], String)...) -> Double? {
        values.lazy.compactMap { signedNumber($0.0, key: $0.1) }.first
    }

    private static func signedNumber(_ dictionary: [String: Any], key: String) -> Double? {
        guard let number = dictionary[key] as? NSNumber else {
            return nil
        }
        let raw = number.uint64Value
        if raw > UInt64(Int64.max) {
            return Double(Int64(bitPattern: raw))
        }
        return number.doubleValue
    }

    private static func firstString(_ values: ([String: Any], String)...) -> String? {
        values.lazy.compactMap { pair in
            (pair.0[pair.1] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.first(where: { !$0.isEmpty })
    }

    private static func adapterIdentity(_ dictionary: [String: Any]) -> String? {
        firstString((dictionary, "Name"), (dictionary, "Model"), (dictionary, "Description"))
    }

    private static func connectionType(_ dictionary: [String: Any]) -> PowerConnectionType {
        if (dictionary["IsWireless"] as? NSNumber)?.boolValue == true {
            return .wireless
        }
        let identity = ["Name", "Description", "Model"]
            .compactMap { dictionary[$0] as? String }
            .joined(separator: " ")
            .lowercased()
        if identity.contains("magsafe") {
            return .magsafe
        }
        if identity.contains("usb-c") || identity.contains("usb c") || identity.contains("pd charger") {
            return .usbC
        }
        return .other
    }

    private func chargeTimeEstimate(_ dictionary: [String: Any], isCharging: Bool) -> BatteryTimeEstimate {
        guard isCharging else {
            return .unavailable
        }
        guard let minutes = Self.number(dictionary, key: kIOPSTimeToFullChargeKey as String) else {
            return .unavailable
        }
        if minutes < 0 {
            return .calculating
        }
        return .estimated(seconds: minutes * 60)
    }

    private func timeEstimate(_ value: TimeInterval, unknownMeansCalculating: Bool) -> BatteryTimeEstimate {
        if value == kIOPSTimeRemainingUnlimited {
            return .unlimited
        }
        if value == kIOPSTimeRemainingUnknown {
            return unknownMeansCalculating ? .calculating : .unavailable
        }
        if value > 0 {
            return .estimated(seconds: value)
        }
        return .unavailable
    }
}
