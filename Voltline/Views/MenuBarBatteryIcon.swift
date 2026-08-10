import SwiftUI

enum MenuBarPercentageMode: String, CaseIterable, Identifiable {
    case outside
    case inside
    case hidden

    var id: Self { self }

    var title: String {
        switch self {
        case .outside: "Outside"
        case .inside: "Inside"
        case .hidden: "Hidden"
        }
    }
}

struct MenuBarBatteryIcon: View {
    let level: Double
    let isCharging: Bool
    let isConnectedToPower: Bool
    let percentageMode: MenuBarPercentageMode
    let colorful: Bool
    let iosShape: Bool
    let hidePercentageAbove: Double

    private var batteryLevel: Int {
        Int(min(max(level, 0), 100).rounded())
    }

    private var hidesPercentage: Bool {
        Double(batteryLevel) > hidePercentageAbove
    }

    private var powerColor: Color {
        if batteryLevel <= 10 {
            return .red
        }
        if batteryLevel <= 20 {
            return .yellow
        }
        return .green
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if percentageMode == .outside && !hidesPercentage {
                Text("\(batteryLevel)%")
                    .font(.system(size: 11))
            }
            if iosShape {
                iosBattery
            } else {
                macOSBattery
            }
        }
        .accessibilityLabel("Battery \(batteryLevel) percent")
    }

    private var macOSBattery: some View {
        let width = round(max(2, min(19, Double(batteryLevel) / 100 * 19)))
        return ZStack(alignment: .leading) {
            Image(colorful || percentageMode == .inside ? "batt_outline_bold" : "batt_outline")
            if percentageMode == .inside && !hidesPercentage {
                AirBatteryLevelView(
                    level: batteryLevel,
                    isCharging: isCharging,
                    isConnectedToPower: isConnectedToPower
                )
                .scaleEffect(0.9)
                .foregroundStyle(colorful ? powerColor : Color.primary)
                .offset(x: batteryLevel < 100 ? -1 : -0.5)
            } else {
                Rectangle()
                    .fill(colorful ? powerColor : batteryLevel <= 10 ? Color.red : Color.primary)
                    .frame(width: width, height: 8, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                    .offset(x: 2)
                if isConnectedToPower {
                    Image(isCharging ? "batt_bolt_mask" : "batt_plug_mask")
                        .blendMode(.destinationOut)
                        .offset(x: 6)
                    Image(isCharging ? "batt_bolt" : "batt_plug")
                        .offset(x: 6)
                        .foregroundStyle(.primary)
                }
            }
        }
        .compositingGroup()
    }

    private var iosBattery: some View {
        ZStack(alignment: .leading) {
            Image("battery.100percent")
                .resizable()
                .scaledToFit()
                .frame(width: 27)
                .opacity(0.4)
                .mask {
                    HStack {
                        Spacer()
                            .frame(minWidth: 0)
                        Rectangle()
                            .frame(width: min(25, CGFloat(100 - batteryLevel) / 100 * 27))
                    }
                }
            Image("battery.100percent")
                .resizable()
                .scaledToFit()
                .foregroundStyle(colorful ? powerColor : batteryLevel <= 10 ? Color.red : Color.primary)
                .frame(width: 27)
                .mask {
                    HStack {
                        Rectangle()
                            .frame(width: max(2, CGFloat(batteryLevel) / 100 * 27))
                        Spacer()
                            .frame(minWidth: 0)
                    }
                }
            if percentageMode == .inside && !hidesPercentage {
                if colorful {
                    AirBatteryLevelView(
                        level: batteryLevel,
                        isCharging: isCharging,
                        isConnectedToPower: isConnectedToPower
                    )
                    .foregroundStyle(.white)
                } else {
                    AirBatteryLevelView(
                        level: batteryLevel,
                        isCharging: isCharging,
                        isConnectedToPower: isConnectedToPower
                    )
                    .foregroundStyle(.white)
                    .blendMode(.destinationOut)
                }
            } else if isConnectedToPower {
                Image(isCharging ? "batt_bolt_mask" : "batt_plug_mask")
                    .blendMode(.destinationOut)
                    .offset(x: 6.5)
                Image(isCharging ? "batt_bolt" : "batt_plug")
                    .offset(x: 6.5)
                    .foregroundStyle(.primary)
            }
        }
        .compositingGroup()
    }
}

private struct AirBatteryLevelView: View {
    let level: Int
    let isCharging: Bool
    let isConnectedToPower: Bool

    var body: some View {
        Group {
            if isConnectedToPower {
                HStack(spacing: -1) {
                    Text("\(level)")
                        .font(.system(size: level > 99 ? 10 : 11, weight: .medium))
                        .tracking(level > 99 ? -0.3 : 0)
                        .offset(y: level > 99 ? 0.4 : 0.5)
                    Image(isCharging ? "bolt.fill" : "powerplug.portrait.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 5)
                        .padding(.leading, 1)
                        .offset(y: level < 100 ? 0.5 : 0)
                }
                .offset(x: level < 100 ? 0.5 : -0.5)
                .offset(y: level < 100 ? -0.5 : 0)
            } else {
                Text("\(level)")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .frame(maxHeight: 12, alignment: .center)
        .frame(maxWidth: 24, alignment: .center)
    }
}
