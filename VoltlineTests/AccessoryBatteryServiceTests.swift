import Foundation
import Testing
@testable import Voltline

struct AccessoryBatteryServiceTests {
    @Test
    func parsesSeparateAirPodsLevels() throws {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "AirPods Pro": {
                    "device_batteryLevelLeft": "64 %",
                    "device_batteryLevelRight": "62 %",
                    "device_batteryLevelCase": "81 %",
                    "device_minorType": "Headphones",
                    "device_serialNumber": "sample"
                  }
                }
              ]
            }
          ]
        }
        """
        let devices = AccessoryBatteryService().parseSystemProfiler(try #require(json.data(using: .utf8)), earbudMergeDifference: 0)
        #expect(devices.count == 3)
        #expect(devices.map(\.level).sorted() == [62, 64, 81])
        #expect(devices.allSatisfy { $0.kind == .headphones })
    }

    @Test
    func mergesSimilarEarbudLevels() throws {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "AirPods Pro": {
                    "device_batteryLevelLeft": "64 %",
                    "device_batteryLevelRight": "62 %",
                    "device_minorType": "Headphones"
                  }
                }
              ]
            }
          ]
        }
        """
        let devices = AccessoryBatteryService().parseSystemProfiler(try #require(json.data(using: .utf8)))
        #expect(devices.count == 1)
        #expect(devices.first?.component == "Earbuds")
        #expect(devices.first?.level == 62)
    }

    @Test
    func ignoresConnectedDevicesWithoutBatteryData() throws {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "iPhone": {
                    "device_minorType": "Phone"
                  }
                }
              ]
            }
          ]
        }
        """
        let devices = AccessoryBatteryService().parseSystemProfiler(try #require(json.data(using: .utf8)))
        #expect(devices.isEmpty)
    }
}
