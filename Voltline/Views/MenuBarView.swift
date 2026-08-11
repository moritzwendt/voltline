import AppKit
import Charts
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text("Voltline")
                    .font(.headline)
                Text(model.currentSnapshot?.chargingState.displayName ?? "Waiting for data")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(VoltlineStyle.subdued)
                Spacer()
                Image(systemName: model.currentSnapshot?.isCharging == true ? "battery.100percent.bolt" : "battery.50percent")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(model.currentSnapshot?.isCharging == true ? VoltlineStyle.amber : VoltlineStyle.mint)
            }

            if let snapshot = model.currentSnapshot {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(snapshot.percentage.rounded()))%")
                        .font(.system(size: 42, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Likely remaining")
                            .font(.caption2)
                            .foregroundStyle(VoltlineStyle.subdued)
                        Text(model.derivedRuntime?.compactDuration ?? snapshot.systemTimeRemaining.displayName)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                }

                miniChart

                HStack {
                    compactMetric("Drain", value: model.recentRate.map { String(format: "%.1f%%/h", $0) } ?? "Learning")
                    Divider().frame(height: 32)
                    compactMetric("Used today", value: String(format: "%.0f%%", model.dayMetrics.batteryUsed))
                    Divider().frame(height: 32)
                    compactMetric("On battery", value: model.dayMetrics.timeOnBattery.compactDuration)
                }

                if !model.visibleAccessories.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Devices")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VoltlineStyle.subdued)
                            Spacer()
                            Button {
                                model.refreshAccessories()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Refresh devices")
                        }
                        ForEach(model.visibleAccessories) { device in
                            deviceRow(device)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Open Dashboard") {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)

                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Settings")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Quit Voltline")
            }
        }
        .padding(18)
        .frame(width: 340)
        .background(VoltlineStyle.canvas)
    }

    private var miniChart: some View {
        Chart(BatteryAnalytics.downsample(samples: model.samples, maxPoints: 90)) { sample in
            LineMark(
                x: .value("Time", sample.timestamp),
                y: .value("Battery", sample.batteryLevel)
            )
            .foregroundStyle(VoltlineStyle.mint)
            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 68)
        .padding(.vertical, 8)
        .background(VoltlineStyle.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("Today’s battery sparkline")
    }

    private func compactMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(VoltlineStyle.subdued)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deviceRow(_ device: BatteryDevice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: device.kind.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(device.level <= model.lowBatteryAlertLevel ? VoltlineStyle.alert : VoltlineStyle.ice)
                .frame(width: 28, height: 28)
                .background(VoltlineStyle.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(device.displayName)
                .font(.subheadline)
                .lineLimit(1)
            if model.isPinned(device) {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(VoltlineStyle.subdued)
            }
            Spacer()
            if device.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(VoltlineStyle.amber)
            }
            Text("\(device.level)%")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button(model.isPinned(device) ? "Unpin" : "Pin") {
                model.togglePin(device)
            }
            Button("Hide") {
                model.hide(device)
            }
        }
    }
}
