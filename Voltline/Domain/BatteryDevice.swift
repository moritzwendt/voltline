import Foundation

enum BatteryDeviceKind: String, Sendable, Codable {
    case headphones
    case mouse
    case keyboard
    case trackpad
    case phone
    case tablet
    case watch
    case speaker
    case accessory

    var symbol: String {
        switch self {
        case .headphones: "airpodspro"
        case .mouse: "computermouse"
        case .keyboard: "keyboard"
        case .trackpad: "rectangle.and.hand.point.up.left"
        case .phone: "iphone"
        case .tablet: "ipad"
        case .watch: "applewatch"
        case .speaker: "hifispeaker"
        case .accessory: "battery.50percent"
        }
    }

    static func infer(name: String, type: String) -> BatteryDeviceKind {
        let value = "\(name) \(type)".lowercased()
        if value.contains("airpod") || value.contains("headphone") || value.contains("beats") {
            return .headphones
        }
        if value.contains("mouse") {
            return .mouse
        }
        if value.contains("keyboard") {
            return .keyboard
        }
        if value.contains("trackpad") {
            return .trackpad
        }
        if value.contains("iphone") || value.contains("айфон") {
            return .phone
        }
        if value.contains("ipad") {
            return .tablet
        }
        if value.contains("watch") {
            return .watch
        }
        if value.contains("speaker") || value.contains("jbl") {
            return .speaker
        }
        return .accessory
    }
}

struct BatteryDevice: Identifiable, Sendable, Equatable, Codable {
    let id: String
    let name: String
    let component: String?
    let kind: BatteryDeviceKind
    let level: Int
    let isCharging: Bool
    let lastSeen: Date

    var displayName: String {
        guard let component else {
            return name
        }
        return "\(name) \(component)"
    }

    func refreshed(at date: Date) -> BatteryDevice {
        BatteryDevice(
            id: id,
            name: name,
            component: component,
            kind: kind,
            level: level,
            isCharging: isCharging,
            lastSeen: date
        )
    }
}
