import Foundation
import IOBluetooth
import IOKit

struct AccessoryBatteryService: Sendable {
    func scan(earbudMergeDifference: Int = 3) -> [BatteryDevice] {
        let profiled = scanSystemProfiler(earbudMergeDifference: earbudMergeDifference)
        let bluetooth = scanPairedBluetooth()
        let registry = scanRegistry()
        var devices: [String: BatteryDevice] = [:]
        let profiledNames = Set(profiled.map { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) })
        let candidates = bluetooth.filter {
            !profiledNames.contains($0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        } + registry + profiled
        for device in candidates {
            let key = device.displayName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            devices[key] = device
        }
        return devices.values.sorted { left, right in
            if left.name == right.name {
                return (left.component ?? "") < (right.component ?? "")
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    func parseSystemProfiler(_ data: Data, date: Date = .now, earbudMergeDifference: Int = 3) -> [BatteryDevice] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]],
              let section = sections.first,
              let connected = section["device_connected"] as? [[String: Any]] else {
            return []
        }

        var result: [BatteryDevice] = []
        for entry in connected {
            guard let name = entry.keys.first,
                  let info = entry[name] as? [String: Any] else {
                continue
            }
            let type = info["device_minorType"] as? String ?? ""
            let identifier = info["device_address"] as? String
                ?? info["device_serialNumber"] as? String
                ?? name
            let kind = BatteryDeviceKind.infer(name: name, type: type)
            let main = percentage(info["device_batteryLevelMain"])
            let left = percentage(info["device_batteryLevelLeft"])
            let right = percentage(info["device_batteryLevelRight"])
            let batteryCase = percentage(info["device_batteryLevelCase"])
            var components: [(String?, Int)] = []
            if let main {
                components.append((nil, main))
            }
            if let left, let right, abs(left - right) <= earbudMergeDifference {
                components.append(("Earbuds", min(left, right)))
            } else {
                if let left {
                    components.append(("Left", left))
                }
                if let right {
                    components.append(("Right", right))
                }
            }
            if let batteryCase {
                components.append(("Case", batteryCase))
            }
            for (component, level) in components {
                let suffix = component?.lowercased() ?? "main"
                result.append(BatteryDevice(
                    id: "bluetooth|\(identifier)|\(suffix)",
                    name: name,
                    component: component,
                    kind: kind,
                    level: level,
                    isCharging: false,
                    lastSeen: date
                ))
            }
        }
        return result
    }

    private func scanSystemProfiler(earbudMergeDifference: Int) -> [BatteryDevice] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "mini"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return []
            }
            return parseSystemProfiler(data, earbudMergeDifference: earbudMergeDifference)
        } catch {
            return []
        }
    }

    private func scanPairedBluetooth() -> [BatteryDevice] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        let date = Date.now
        return paired.compactMap { device in
            guard device.isConnected(),
                  let name = device.name,
                  let value = dynamicValue(device, key: "batteryPercentSingle"),
                  let level = percentage(value),
                  level > 0 else {
                return nil
            }
            let identifier = device.addressString ?? name
            return BatteryDevice(
                id: "bluetooth|\(identifier)|main",
                name: name,
                component: nil,
                kind: BatteryDeviceKind.infer(name: name, type: ""),
                level: level,
                isCharging: false,
                lastSeen: date
            )
        }
    }

    private func scanRegistry() -> [BatteryDevice] {
        let classes = [
            "AppleDeviceManagementHIDEventService",
            "AppleBluetoothHIDKeyboard",
            "BNBTrackpadDevice",
            "BNBMouseDevice"
        ]
        var result: [BatteryDevice] = []
        for className in classes {
            var iterator: io_iterator_t = 0
            guard let matching = IOServiceMatching(className),
                  IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(iterator) }
            while true {
                let entry = IOIteratorNext(iterator)
                guard entry != 0 else {
                    break
                }
                defer { IOObjectRelease(entry) }
                var properties: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                      let values = properties?.takeRetainedValue() as? [String: Any],
                      let name = values["Product"] as? String,
                      !name.localizedCaseInsensitiveContains("Internal"),
                      let level = percentage(values["BatteryPercent"]) else {
                    continue
                }
                let identifier = values["DeviceAddress"] as? String
                    ?? values["SerialNumber"] as? String
                    ?? name
                let flags = (values["BatteryStatusFlags"] as? NSNumber)?.intValue ?? 0
                result.append(BatteryDevice(
                    id: "registry|\(identifier)|main",
                    name: name,
                    component: nil,
                    kind: BatteryDeviceKind.infer(name: name, type: className),
                    level: level,
                    isCharging: flags == 1 || flags == 2,
                    lastSeen: .now
                ))
            }
        }
        return result
    }

    private func dynamicValue(_ device: IOBluetoothDevice, key: String) -> Any? {
        let selector = Selector(key)
        guard device.responds(to: selector) else {
            return nil
        }
        return device.value(forKey: key)
    }

    private func percentage(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return min(max(number.intValue, 0), 100)
        }
        guard let text = value as? String else {
            return nil
        }
        let digits = text.filter(\.isNumber)
        guard let number = Int(digits) else {
            return nil
        }
        return min(max(number, 0), 100)
    }
}
