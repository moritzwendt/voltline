import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let snapshot = model.currentSnapshot {
                        currentHero(snapshot)
                        if geometry.size.width >= 1040 {
                            HStack(alignment: .top, spacing: 18) {
                                chartPanel
                                    .frame(minWidth: 620)
                                sessionPanel
                                    .frame(width: 286)
                            }
                        } else {
                            VStack(spacing: 18) {
                                chartPanel
                                sessionPanel
                            }
                        }
                    } else {
                        unavailableState
                    }
                }
                .padding(32)
                .frame(maxWidth: 1320, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 12) {
                Text("Overview")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                if model.demoMode {
                    Label("Sample data", systemImage: "testtube.2")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(VoltlineStyle.ice)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VoltlineStyle.ice.opacity(0.1), in: Capsule())
                }
            }
            Spacer()
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    DatePicker("Day", selection: Binding(
                        get: { model.selectedDate },
                        set: { model.selectDate($0) }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .glassEffect(.regular.interactive(), in: Capsule())

                    Button {
                        model.selectDate(.now)
                    } label: {
                        Label("Today", systemImage: "calendar.day.timeline.leading")
                            .frame(height: 38)
                    }
                    .buttonStyle(.glass)
                    .keyboardShortcut("t", modifiers: [.command])
                }
            }
        }
    }

    private func currentHero(_ snapshot: BatterySnapshot) -> some View {
        HStack(alignment: .center, spacing: 0) {
            heroMetric(
                label: snapshot.powerSource == .battery ? "On battery" : "External power",
                value: "\(Int(snapshot.percentage.rounded()))%",
                color: snapshot.isCharging ? VoltlineStyle.amber : VoltlineStyle.mint
            )
            Divider().frame(height: 82)
            heroMetric(
                label: "Hourly drain",
                value: model.recentRate.map { String(format: "%.1f%%/h", $0) } ?? "Collecting",
                color: VoltlineStyle.ice
            )
            Divider().frame(height: 82)
            heroMetric(
                label: model.derivedRuntime == nil ? "System estimate" : "Estimated remaining",
                value: model.derivedRuntime?.compactDuration ?? snapshot.systemTimeRemaining.displayName,
                color: VoltlineStyle.amber
            )
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 10) {
                statusPill(
                    snapshot.lowPowerModeEnabled ? "Low Power Mode on" : "Low Power Mode off",
                    symbol: "leaf.fill",
                    color: snapshot.lowPowerModeEnabled ? VoltlineStyle.mint : VoltlineStyle.subdued
                )
                statusPill(
                    snapshot.displayActive ? "Display active" : "Display inactive",
                    symbol: "display",
                    color: VoltlineStyle.ice
                )
            }
        }
        .padding(26)
        .voltlinePanel(cornerRadius: 28)
    }

    private func heroMetric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(VoltlineStyle.subdued)
            }
            Text(value)
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: 250, alignment: .leading)
        .padding(.horizontal, 22)
    }

    private func statusPill(_ title: String, symbol: String, color: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.09), in: Capsule())
    }

    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Battery timeline")
                    .font(.title3.weight(.semibold))
                Text(model.selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(VoltlineStyle.subdued)
                Spacer()
                ChartLegend()
            }
            BatteryTimelineChart(samples: model.samples)
                .frame(height: 360)
        }
        .padding(24)
        .voltlinePanel()
    }

    private var sessionPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Day at a glance")
                .font(.title3.weight(.semibold))
            MetricRow(label: "Battery used", value: String(format: "%.0f%%", model.dayMetrics.batteryUsed), symbol: "battery.25percent", color: VoltlineStyle.mint)
            MetricRow(label: "On battery", value: model.dayMetrics.timeOnBattery.compactDuration, symbol: "bolt.slash", color: VoltlineStyle.ice)
            MetricRow(label: "Display active", value: model.dayMetrics.activeTime.compactDuration, symbol: "display", color: VoltlineStyle.amber)
            MetricRow(label: "Average drain", value: model.dayMetrics.averageDrainRate.map { String(format: "%.1f%%/h", $0) } ?? "Learning", symbol: "gauge.with.dots.needle.67percent", color: VoltlineStyle.alert)
            Divider()
            HStack {
                Text("Discharge sessions")
                    .foregroundStyle(VoltlineStyle.subdued)
                Spacer()
                Text("\(model.dayMetrics.sessionCount)")
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.medium))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .voltlinePanel()
    }

    private var unavailableState: some View {
        ContentUnavailableView(
            model.lastError ?? "Waiting for the first battery measurement",
            systemImage: "battery.0percent"
        )
        .frame(maxWidth: .infinity, minHeight: 480)
        .voltlinePanel()
    }
}

private struct MetricRow: View {
    let label: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(VoltlineStyle.subdued)
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

private struct ChartLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            Label("Battery", systemImage: "circle.fill")
                .foregroundStyle(VoltlineStyle.mint)
            Label("Charging", systemImage: "bolt.fill")
                .foregroundStyle(VoltlineStyle.amber)
        }
        .font(.caption.weight(.medium))
    }
}

extension ChargingState {
    var displayName: String {
        switch self {
        case .charging: "Charging"
        case .charged: "Fully charged"
        case .discharging: "Discharging"
        case .connectedNotCharging: "Power connected"
        case .unknown: "State unavailable"
        }
    }
}

extension BatteryTimeEstimate {
    var displayName: String {
        switch self {
        case let .estimated(seconds): seconds.compactDuration
        case .calculating: "Calculating"
        case .unlimited: "Connected"
        case .unavailable: "Unavailable"
        }
    }
}
