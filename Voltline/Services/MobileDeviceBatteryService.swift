import Foundation

struct MobileDeviceBatteryService: Sendable {
    func scan() -> [BatteryDevice] {
        guard let bin = Bundle.main.resourceURL?
            .appending(path: "libimobiledevice", directoryHint: .isDirectory)
            .appending(path: "bin", directoryHint: .isDirectory) else {
            return []
        }
        var discovered: [String: BatteryDevice] = [:]
        for connection in ["-n", "-l"] {
            let idArguments = connection == "-n" ? ["-n"] : ["-l"]
            guard let output = run(bin.appending(path: "idevice_id"), arguments: idArguments, timeout: 8) else {
                continue
            }
            for identifier in output.components(separatedBy: .newlines).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !identifier.isEmpty {
                if let device = readDevice(identifier: identifier, connection: connection, bin: bin) {
                    discovered[device.id] = device
                    if let watch = readWatch(identifier: identifier, parentName: device.name, bin: bin) {
                        discovered[watch.id] = watch
                    }
                }
            }
        }
        return Array(discovered.values)
    }

    private func readDevice(identifier: String, connection: String, bin: URL) -> BatteryDevice? {
        let prefix = connection == "-n" ? ["-n"] : []
        if connection == "-l" {
            _ = run(bin.appending(path: "wificonnection"), arguments: ["-u", identifier, "true"], timeout: 5)
        }
        guard let info = run(bin.appending(path: "ideviceinfo"), arguments: prefix + ["-u", identifier], timeout: 10),
              let name = value(named: "DeviceName", in: info),
              let type = value(named: "DeviceClass", in: info),
              let battery = run(
                bin.appending(path: "ideviceinfo"),
                arguments: prefix + ["-u", identifier, "-q", "com.apple.mobile.battery"],
                timeout: 10
              ),
              let levelText = value(named: "BatteryCurrentCapacity", in: battery),
              let level = Int(levelText) else {
            return nil
        }
        let charging = value(named: "BatteryIsCharging", in: battery)?.lowercased() == "true"
        return BatteryDevice(
            id: "mobile|\(identifier)|main",
            name: name,
            component: nil,
            kind: BatteryDeviceKind.infer(name: name, type: type),
            level: min(max(level, 0), 100),
            isCharging: charging,
            lastSeen: .now
        )
    }

    private func readWatch(identifier: String, parentName: String, bin: URL) -> BatteryDevice? {
        guard let output = run(bin.appending(path: "comptest"), arguments: [identifier], timeout: 10),
              let watchID = output.components(separatedBy: .newlines)
                .first(where: { $0.contains("Checking watch") })?
                .components(separatedBy: .whitespaces)
                .last,
              let name = value(named: "DeviceName", in: output),
              let levelText = value(named: "BatteryCurrentCapacity", in: output),
              let level = Int(levelText) else {
            return nil
        }
        let charging = value(named: "BatteryIsCharging", in: output)?.lowercased() == "true"
        return BatteryDevice(
            id: "mobile|\(watchID)|main",
            name: name,
            component: nil,
            kind: .watch,
            level: min(max(level, 0), 100),
            isCharging: charging,
            lastSeen: .now
        )
    }

    private func value(named key: String, in output: String) -> String? {
        output.components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix("\(key):") })?
            .split(separator: ":", maxSplits: 1)
            .last
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func run(_ executable: URL, arguments: [String], timeout: TimeInterval) -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            return nil
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = arguments
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
