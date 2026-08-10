import Foundation
import IOBluetooth

final class EnhancedBluetoothBatteryService: @unchecked Sendable {
    private let lock = NSLock()
    private var completedLongScan = false

    func scan() -> [BatteryDevice] {
        lock.lock()
        let longScan = !completedLongScan
        completedLongScan = true
        lock.unlock()

        guard let script = Bundle.main.resourceURL?.appending(path: "logReader.sh"),
              let output = run(script: script, window: longScan ? "2h" : "10m", timeout: longScan ? 25 : 12) else {
            return []
        }
        let connected = connectedAddresses()
        var devices: [String: BatteryDevice] = [:]
        for line in output.components(separatedBy: .newlines) where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let entry = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let mac = entry["mac"] as? String,
                  connected.contains(normalize(mac: mac)),
                  let level = entry["level"] as? Int else {
                continue
            }
            let type = entry["type"] as? String ?? "hid"
            let rawName = entry["name"] as? String ?? ""
            let name = rawName.isEmpty ? "\(type) (\(mac))" : rawName
            let status = entry["status"] as? String ?? ""
            let id = "enhanced|\(normalize(mac: mac))|main"
            devices[id] = BatteryDevice(
                id: id,
                name: name,
                component: nil,
                kind: BatteryDeviceKind.infer(name: name, type: type),
                level: min(max(level, 0), 100),
                isCharging: status == "+",
                lastSeen: .now
            )
        }
        return Array(devices.values)
    }

    private func connectedAddresses() -> Set<String> {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        return Set(paired.filter { $0.isConnected() }.compactMap { device in
            device.addressString.map(normalize(mac:))
        })
    }

    private func normalize(mac: String) -> String {
        mac.uppercased().replacingOccurrences(of: "-", with: ":")
    }

    private func run(script: URL, window: String, timeout: TimeInterval) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, "mac", window]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let deadline = Date.now.addingTimeInterval(timeout)
        while process.isRunning && Date.now < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
