import SwiftUI

struct PowerView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedRange: PowerGraphRange = .oneHour
    @State private var selectedMetric: PowerGraphMetric = .systemPower
    @State private var customStart = Date.now.addingTimeInterval(-24 * 60 * 60)
    @State private var customEnd = Date.now
    @State private var graphSamples: [BatterySamplePoint] = []

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let snapshot = model.currentSnapshot {
                        if geometry.size.width >= 1080 {
                            HStack(alignment: .top, spacing: 18) {
                                PowerFlowView(snapshot: snapshot)
                                    .frame(minWidth: 650)
                                measurements(snapshot)
                                    .frame(width: 350)
                            }
                        } else {
                            PowerFlowView(snapshot: snapshot)
                            measurements(snapshot)
                        }
                        graphPanel
                    } else {
                        unavailableState
                    }
                }
                .padding(32)
                .frame(maxWidth: 1320, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            resetCustomRange()
            reloadSamples()
        }
        .onChange(of: selectedRange) {
            reloadSamples()
        }
        .onChange(of: customStart) {
            if selectedRange == .custom {
                reloadSamples()
            }
        }
        .onChange(of: customEnd) {
            if selectedRange == .custom {
                reloadSamples()
            }
        }
        .onChange(of: model.currentSnapshot?.timestamp) {
            if selectedRange != .custom {
                reloadSamples()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Power")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
            Spacer()
            if let timestamp = model.currentSnapshot?.timestamp {
                Text(timestamp.formatted(date: .omitted, time: .standard))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(VoltlineStyle.subdued)
            }
        }
    }

    private func measurements(_ snapshot: BatterySnapshot) -> some View {
        let electrical = snapshot.electrical
        return VStack(alignment: .leading, spacing: 18) {
            Text("Live measurements")
                .font(.title3.weight(.semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                PowerMeasurement(label: "Voltage", value: format(electrical.voltageVolts, unit: "V", decimals: 2), color: VoltlineStyle.ice)
                PowerMeasurement(label: "Current", value: format(electrical.amperageAmps, unit: "A", decimals: 2), color: currentColor(snapshot))
                PowerMeasurement(label: "Temperature", value: format(electrical.temperatureCelsius, unit: "°C", decimals: 1), color: VoltlineStyle.amber)
                PowerMeasurement(label: "Charging speed", value: chargingSpeed(snapshot), color: VoltlineStyle.amber)
                PowerMeasurement(label: "Current capacity", value: capacity(electrical.currentCapacityMilliampHours), color: VoltlineStyle.mint)
                PowerMeasurement(label: "Full capacity", value: capacity(electrical.fullChargeCapacityMilliampHours), color: VoltlineStyle.mint)
                PowerMeasurement(label: "Design capacity", value: capacity(electrical.designCapacityMilliampHours), color: VoltlineStyle.subdued)
                PowerMeasurement(label: "Completion", value: snapshot.timeUntilFull.displayName, color: VoltlineStyle.ice)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 292, alignment: .topLeading)
        .voltlinePanel()
    }

    private var graphPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Text("Power history")
                    .font(.title3.weight(.semibold))
                Picker("Measurement", selection: $selectedMetric) {
                    ForEach(PowerGraphMetric.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Spacer()
                Picker("Range", selection: $selectedRange) {
                    ForEach(PowerGraphRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)
            }

            if selectedRange == .custom {
                HStack(spacing: 12) {
                    DatePicker("From", selection: $customStart, in: ...customEnd, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("To", selection: $customEnd, in: customStart...Date.now, displayedComponents: [.date, .hourAndMinute])
                    Spacer()
                }
                .datePickerStyle(.field)
            }

            PowerHistoryChart(samples: graphSamples, metric: selectedMetric)
                .frame(height: 380)
        }
        .padding(24)
        .voltlinePanel()
    }

    private var unavailableState: some View {
        ContentUnavailableView(
            model.lastError ?? "Waiting for power measurements",
            systemImage: "bolt.horizontal.circle"
        )
        .frame(maxWidth: .infinity, minHeight: 520)
        .voltlinePanel()
    }

    private func reloadSamples() {
        let end: Date
        let start: Date
        if selectedRange == .custom {
            start = customStart
            end = customEnd
        } else {
            end = model.currentSnapshot?.timestamp ?? .now
            start = end.addingTimeInterval(0 - (selectedRange.duration ?? 0))
        }
        graphSamples = model.powerSamples(from: start, through: end)
    }

    private func resetCustomRange() {
        let end = model.currentSnapshot?.timestamp ?? .now
        customEnd = end
        customStart = end.addingTimeInterval(-24 * 60 * 60)
    }

    private func format(_ value: Double?, unit: String, decimals: Int) -> String {
        guard let value else {
            return "Unavailable"
        }
        return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(unit)"
    }

    private func capacity(_ value: Double?) -> String {
        guard let value else {
            return "Unavailable"
        }
        return "\(Int(value.rounded()).formatted()) mAh"
    }

    private func chargingSpeed(_ snapshot: BatterySnapshot) -> String {
        guard let watts = snapshot.electrical.batteryPowerWatts, watts < 0 else {
            return "Unavailable"
        }
        return format(abs(watts), unit: "W", decimals: 1)
    }

    private func currentColor(_ snapshot: BatterySnapshot) -> Color {
        if snapshot.isCharging {
            return VoltlineStyle.amber
        }
        return snapshot.powerSource == .battery ? VoltlineStyle.mint : VoltlineStyle.ice
    }
}

private struct PowerMeasurement: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(VoltlineStyle.subdued)
            }
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PowerFlowView: View {
    let snapshot: BatterySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Live power flow")
                .font(.title3.weight(.semibold))
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let adapterPoint = CGPoint(x: width * 0.15, y: height * 0.31)
                let junctionPoint = CGPoint(x: width * 0.48, y: height * 0.31)
                let macPoint = CGPoint(x: width * 0.82, y: height * 0.31)
                let batteryPoint = CGPoint(x: width * 0.48, y: height * 0.79)

                Canvas { context, _ in
                    drawLine(context: &context, from: adapterPoint, to: junctionPoint, color: adapterLineColor)
                    drawLine(context: &context, from: junctionPoint, to: macPoint, color: macLineColor)
                    drawLine(context: &context, from: junctionPoint, to: batteryPoint, color: batteryLineColor)
                }

                flowArrow(symbol: "chevron.right", color: adapterLineColor)
                    .position(x: width * 0.315, y: height * 0.31)
                flowArrow(symbol: "chevron.right", color: macLineColor)
                    .position(x: width * 0.65, y: height * 0.31)
                flowArrow(symbol: batteryArrow, color: batteryLineColor)
                    .position(x: width * 0.48, y: height * 0.55)

                flowNode(
                    title: "Adapter input",
                    value: watts(snapshot.electrical.adapterPowerWatts),
                    secondary: "Capacity \(watts(snapshot.electrical.adapterCapacityWatts))",
                    symbol: "powerplug.fill",
                    color: VoltlineStyle.ice
                )
                .frame(width: min(188, width * 0.27))
                .position(adapterPoint)

                flowNode(
                    title: "Mac consumption",
                    value: watts(snapshot.electrical.systemPowerWatts),
                    secondary: snapshot.powerSource == .battery ? "From battery" : "External power",
                    symbol: "laptopcomputer",
                    color: macLineColor
                )
                .frame(width: min(188, width * 0.27))
                .position(macPoint)

                flowNode(
                    title: batteryTitle,
                    value: batteryWatts,
                    secondary: "\(Int(snapshot.percentage.rounded()))%",
                    symbol: snapshot.isCharging ? "battery.100percent.bolt" : "battery.75percent",
                    color: batteryLineColor
                )
                .frame(width: min(202, width * 0.3))
                .position(batteryPoint)

                Circle()
                    .fill(macLineColor)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle().stroke(macLineColor.opacity(0.3), lineWidth: 8)
                    }
                    .position(junctionPoint)
            }
            .frame(height: 225)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 292, alignment: .topLeading)
        .voltlinePanel()
    }

    private var adapterLineColor: Color {
        snapshot.electrical.adapterPowerWatts == nil ? VoltlineStyle.subdued : VoltlineStyle.ice
    }

    private var macLineColor: Color {
        snapshot.powerSource == .battery ? VoltlineStyle.mint : VoltlineStyle.ice
    }

    private var batteryLineColor: Color {
        switch snapshot.electrical.batteryPowerDirection {
        case .charging: VoltlineStyle.amber
        case .discharging: VoltlineStyle.mint
        case .idle, nil: VoltlineStyle.subdued
        }
    }

    private var batteryTitle: String {
        switch snapshot.electrical.batteryPowerDirection {
        case .charging: "Battery charging"
        case .discharging: "Battery discharge"
        case .idle: "Battery idle"
        case nil: "Battery power"
        }
    }

    private var batteryWatts: String {
        snapshot.electrical.batteryPowerWatts.map { watts(abs($0)) } ?? "Unavailable"
    }

    private var batteryArrow: String {
        snapshot.electrical.batteryPowerDirection == .discharging ? "chevron.up" : "chevron.down"
    }

    private func drawLine(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color.opacity(0.76)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private func flowArrow(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 24, height: 24)
            .background(VoltlineStyle.surface, in: Circle())
            .overlay {
                Circle().strokeBorder(color.opacity(0.24))
            }
    }

    private func flowNode(
        title: String,
        value: String,
        secondary: String,
        symbol: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(secondary)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(VoltlineStyle.subdued)
                .lineLimit(1)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VoltlineStyle.raised, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(color.opacity(0.18))
        }
    }

    private func watts(_ value: Double?) -> String {
        guard let value else {
            return "Unavailable"
        }
        return watts(value)
    }

    private func watts(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)))) W"
    }
}
