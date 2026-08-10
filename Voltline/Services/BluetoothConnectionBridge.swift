import Foundation
import IOBluetooth

@MainActor
final class BluetoothConnectionBridge: NSObject {
    private let onConnect: () -> Void
    private var notification: IOBluetoothUserNotification?

    init(onConnect: @escaping () -> Void) {
        self.onConnect = onConnect
        super.init()
        notification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceIsConnected(notification:fromDevice:))
        )
    }

    @objc nonisolated private func deviceIsConnected(
        notification: IOBluetoothUserNotification,
        fromDevice device: IOBluetoothDevice
    ) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.onConnect()
        }
    }
}
