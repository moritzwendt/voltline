@preconcurrency import CoreBluetooth
import Foundation

@MainActor
final class BLEAccessoryScanner: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    var isEnabled = true
    var readsGenericDevices = true
    var readsIOSDevices = true
    var earbudMergeDifference = 3
    var onDevicesChanged: (([BatteryDevice]) -> Void)?

    private var manager: CBCentralManager!
    private var scanTimer: Timer?
    private var connected: [UUID: CBPeripheral] = [:]
    private var devices: [String: BatteryDevice] = [:]
    private var previousLevels: [UUID: Int] = [:]
    private var lastConnectionAttempt: [UUID: Date] = [:]

    override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: .main)
    }

    func start(interval: TimeInterval) {
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: max(interval, 30), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scan(duration: 5)
            }
        }
        scan(duration: 15)
    }

    func stop() {
        scanTimer?.invalidate()
        scanTimer = nil
        manager.stopScan()
    }

    func scan(duration: TimeInterval = 5) {
        guard isEnabled, manager.state == .poweredOn, !manager.isScanning else {
            return
        }
        manager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            self?.manager.stopScan()
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            scan(duration: 15)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isEnabled else {
            return
        }
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advertisedName
        if let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
           data.count >= 3,
           data[0] == 76 {
            if data.count == 25, data[2] == 18 {
                updateAirPods(peripheral: peripheral, name: name, data: data, open: false)
            } else if data.count == 29, data[2] == 7 {
                updateAirPods(peripheral: peripheral, name: name, data: data, open: true)
            } else if readsIOSDevices, [UInt8(16), UInt8(12)].contains(data[2]), let name, !name.isEmpty {
                connect(peripheral: peripheral, with: central)
            }
            return
        }
        guard readsGenericDevices, let name, !name.isEmpty else {
            return
        }
        connect(peripheral: peripheral, with: central)
    }

    private func connect(peripheral: CBPeripheral, with central: CBCentralManager) {
        let lastAttempt = lastConnectionAttempt[peripheral.identifier] ?? .distantPast
        guard Date.now.timeIntervalSince(lastAttempt) >= 60 else {
            return
        }
        lastConnectionAttempt[peripheral.identifier] = .now
        connected[peripheral.identifier] = peripheral
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: "180F")])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connected.removeValue(forKey: peripheral.identifier)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            manager.cancelPeripheralConnection(peripheral)
            connected.removeValue(forKey: peripheral.identifier)
            return
        }
        for service in services where service.uuid == CBUUID(string: "180F") {
            peripheral.discoverCharacteristics([CBUUID(string: "2A19")], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        for characteristic in characteristics where characteristic.uuid == CBUUID(string: "2A19") {
            peripheral.readValue(for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == CBUUID(string: "2A19"),
              let byte = characteristic.value?.first,
              byte <= 100,
              let name = peripheral.name else {
            return
        }
        let level = Int(byte)
        let charging = previousLevels[peripheral.identifier].map { level > $0 } ?? false
        previousLevels[peripheral.identifier] = level
        let id = "ble|\(peripheral.identifier.uuidString)|main"
        devices[id] = BatteryDevice(
            id: id,
            name: name,
            component: nil,
            kind: BatteryDeviceKind.infer(name: name, type: "ble"),
            level: level,
            isCharging: charging,
            lastSeen: .now
        )
        publish()
        manager.cancelPeripheralConnection(peripheral)
        connected.removeValue(forKey: peripheral.identifier)
    }

    private func updateAirPods(peripheral: CBPeripheral, name: String?, data: Data, open: Bool) {
        let deviceName = name ?? headphoneModel(data: data, open: open)
        let identifier = peripheral.identifier.uuidString
        let model = headphoneModel(data: data, open: open)
        let flip = open && ((data[7] >> 4) & 0x02) == 0
        let caseValue = batteryValue(data[open ? 16 : 12])
        let leftValue = batteryValue(data[open ? (flip ? 15 : 14) : 13])
        let rightValue = batteryValue(data[open ? (flip ? 14 : 15) : 14])
        var updates: [BatteryDevice] = []

        if let caseValue {
            updates.append(device(identifier: identifier, suffix: "case", name: deviceName, component: "Case", model: model, value: caseValue))
        }
        if let leftValue, let rightValue,
           abs(leftValue.level - rightValue.level) <= earbudMergeDifference,
           leftValue.charging == rightValue.charging {
            updates.append(device(identifier: identifier, suffix: "earbuds", name: deviceName, component: "Earbuds", model: model, value: (min(leftValue.level, rightValue.level), leftValue.charging)))
            devices.removeValue(forKey: "ble|\(identifier)|left")
            devices.removeValue(forKey: "ble|\(identifier)|right")
        } else {
            devices.removeValue(forKey: "ble|\(identifier)|earbuds")
            if let leftValue {
                updates.append(device(identifier: identifier, suffix: "left", name: deviceName, component: "Left", model: model, value: leftValue))
            }
            if let rightValue {
                updates.append(device(identifier: identifier, suffix: "right", name: deviceName, component: "Right", model: model, value: rightValue))
            }
        }
        for update in updates {
            devices[update.id] = update
        }
        publish()
    }

    private func device(
        identifier: String,
        suffix: String,
        name: String,
        component: String,
        model: String,
        value: (level: Int, charging: Bool)
    ) -> BatteryDevice {
        BatteryDevice(
            id: "ble|\(identifier)|\(suffix)",
            name: name,
            component: component,
            kind: BatteryDeviceKind.infer(name: name, type: model),
            level: value.level,
            isCharging: value.charging,
            lastSeen: .now
        )
    }

    private func batteryValue(_ raw: UInt8) -> (level: Int, charging: Bool)? {
        guard raw != 255 else {
            return nil
        }
        let charging = raw > 100
        let level = Int(charging ? raw & 0x7F : raw)
        guard level <= 100 else {
            return nil
        }
        return (level, charging)
    }

    private func headphoneModel(data: Data, open: Bool) -> String {
        guard open, data.count > 6 else {
            return "AirPods Pro 2"
        }
        let code = String(format: "%02x%02x", data[6], data[5])
        switch code {
        case "2002": return "AirPods"
        case "200e": return "AirPods Pro"
        case "200a", "201f": return "AirPods Max"
        case "200f": return "AirPods 2"
        case "2013": return "AirPods 3"
        case "201b", "2019": return "AirPods 4"
        case "2014", "2024": return "AirPods Pro 2"
        case "2003": return "PowerBeats 3"
        case "200d": return "PowerBeats 4"
        case "200b": return "PowerBeats Pro"
        case "200c": return "Beats Solo Pro"
        case "2011": return "Beats Studio Buds"
        case "2010": return "Beats Flex"
        case "2005": return "BeatsX"
        case "2006": return "Beats Solo 3"
        case "2009": return "Beats Studio 3"
        case "2017": return "Beats Studio Pro"
        case "2012": return "Beats Fit Pro"
        case "2016": return "Beats Studio Buds+"
        default: return "Headphones"
        }
    }

    private func publish() {
        onDevicesChanged?(Array(devices.values))
    }
}
