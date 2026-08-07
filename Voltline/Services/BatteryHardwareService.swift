import CoreGraphics
import Foundation
import IOKit.ps

struct BatteryHardwareService: Sendable {
    enum ServiceError: Error {
        case powerSourceUnavailable
        case batteryUnavailable
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

        let current = number(description, key: kIOPSCurrentCapacityKey as String) ?? 0
        let maximum = max(number(description, key: kIOPSMaxCapacityKey as String) ?? 100, 1)
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
            warningState: .unavailable
        )
    }

    private func number(_ dictionary: [String: Any], key: String) -> Double? {
        (dictionary[key] as? NSNumber)?.doubleValue
    }

    private func chargeTimeEstimate(_ dictionary: [String: Any], isCharging: Bool) -> BatteryTimeEstimate {
        guard isCharging else {
            return .unavailable
        }
        guard let minutes = number(dictionary, key: kIOPSTimeToFullChargeKey as String) else {
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

