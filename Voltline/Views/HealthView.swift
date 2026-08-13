import SwiftUI

struct HealthView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedRange: HealthHistoryRange = .thirtyDays
    @State private var healthSnapshots: [DailyHealthSnapshotPoint] = []
    @State private var exposure = HealthExposureMetrics(
        measuredDuration: 0,
        aboveEightyDuration: nil,
        belowTwentyDuration: nil,
        aboveThirtyFiveDuration: nil,
        atFullDuration: nil,
        recommendedRangeDuration: nil,
        equivalentFullCycles: nil
    )

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let snapshot = model.currentSnapshot {
                        healthSummary(snapshot, wide: geometry.size.width >= 1080)
                        HealthHistoryGrid(snapshots: healthSnapshots)
                        if geometry.size.width >= 960 {
                            HStack(alignment: .top, spacing: 18) {
                                exposurePanel
                                estimatePanel(snapshot)
                                    .frame(width: 390)
                            }
                        } else {
                            exposurePanel
                            estimatePanel(snapshot)
                                .frame(maxWidth: .infinity)
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
        .onAppear {
            reload()
        }
        .onChange(of: selectedRange) {
            reload()
        }
        .onChange(of: model.currentSnapshot?.timestamp) {
            reload()
        }
    }

    private var header: some View {
        HStack {
            Text("Health")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
            Spacer()
            Picker("Range", selection: $selectedRange) {
                ForEach(HealthHistoryRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 430)
        }
    }

    private func healthSummary(_ snapshot: BatterySnapshot, wide: Bool) -> some View {
        let electrical = snapshot.electrical
        return Group {
            if wide {
                HStack(alignment: .top, spacing: 0) {
                    capacitySummary(electrical)
                        .padding(26)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                        .padding(.vertical, 24)
                    healthDetails(snapshot)
                        .padding(26)
                        .frame(width: 500)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    capacitySummary(electrical)
                        .padding(26)
                    Divider()
                    healthDetails(snapshot)
                        .padding(26)
                }
            }
        }
        .voltlinePanel(cornerRadius: 28)
    }

    private func capacitySummary(_ electrical: BatteryElectricalTelemetry) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Capacity health")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(VoltlineStyle.subdued)
                    Text(healthPercentage(electrical))
                        .font(.system(size: 44, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                statusPill(electrical.condition ?? "Condition unavailable")
            }
            capacityBand(electrical)
        }
    }

    private func healthDetails(_ snapshot: BatterySnapshot) -> some View {
        let electrical = snapshot.electrical
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            summaryMetric("Cycle count", value: electrical.cycleCount?.formatted() ?? "Unavailable", color: VoltlineStyle.ice)
            summaryMetric("Temperature", value: value(electrical.temperatureCelsius, unit: "°C", decimals: 1), color: VoltlineStyle.amber)
            summaryMetric("Hardware percentage", value: value(electrical.hardwarePercentage, unit: "%", decimals: 0), color: VoltlineStyle.mint)
            summaryMetric("Battery age", value: batteryAge(electrical.manufactureDate, reference: snapshot.timestamp), color: VoltlineStyle.ice)
            summaryMetric("Manufactured", value: electrical.manufactureDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unavailable", color: VoltlineStyle.subdued)
            summaryMetric("Chemical health", value: "Not determined", color: VoltlineStyle.subdued)
        }
    }

    private func capacityBand(_ electrical: BatteryElectricalTelemetry) -> some View {
        let full = electrical.fullChargeCapacityMilliampHours
        let design = electrical.designCapacityMilliampHours
        let ratio = HealthAnalytics.healthPercentage(fullChargeCapacity: full, designCapacity: design).map { min(max($0 / 100, 0), 1) } ?? 0
        return VStack(spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(VoltlineStyle.raised)
                    Capsule()
                        .fill(LinearGradient(colors: [VoltlineStyle.mint.opacity(0.7), VoltlineStyle.mint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * ratio)
                }
            }
            .frame(height: 12)
            HStack {
                capacityLabel("Full charge", value: full)
                Spacer()
                capacityLabel("Design", value: design)
            }
        }
    }

    private func capacityLabel(_ label: String, value: Double?) -> some View {
        VStack(alignment: label == "Design" ? .trailing : .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(VoltlineStyle.subdued)
            Text(capacity(value))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func summaryMetric(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(VoltlineStyle.subdued)
            }
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exposurePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Battery exposure")
                .font(.title3.weight(.semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                exposureMetric("Above 80 percent", duration: exposure.aboveEightyDuration, color: VoltlineStyle.amber)
                exposureMetric("Below 20 percent", duration: exposure.belowTwentyDuration, color: VoltlineStyle.alert)
                exposureMetric("Above 35 °C", duration: exposure.aboveThirtyFiveDuration, color: VoltlineStyle.alert)
                exposureMetric("At 100 percent", duration: exposure.atFullDuration, color: VoltlineStyle.amber)
                exposureMetric("Recommended range", duration: exposure.recommendedRangeDuration, color: VoltlineStyle.mint)
                exposureValue("Equivalent full cycles", value: exposure.equivalentFullCycles.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "Unavailable", color: VoltlineStyle.ice)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .voltlinePanel()
    }

    private func estimatePanel(_ snapshot: BatterySnapshot) -> some View {
        let trend = HealthAnalytics.capacityTrend(
            snapshots: healthSnapshots,
            referenceDate: snapshot.timestamp
        )
        return VStack(alignment: .leading, spacing: 20) {
            Text("Capacity estimates")
                .font(.title3.weight(.semibold))
            estimateRow(
                "Monthly change estimate",
                value: trend.map { "\($0.monthlyCapacityChangeMilliampHours.formatted(.number.precision(.fractionLength(0)))) mAh" } ?? "Unavailable"
            )
            estimateRow(
                "Six month health estimate",
                value: trend.map { "\($0.estimatedHealthInSixMonths.formatted(.number.precision(.fractionLength(1))))%" } ?? "Unavailable"
            )
            estimateRow(
                "80 percent date estimate",
                value: trend?.estimatedDateAtEightyPercent?.formatted(date: .abbreviated, time: .omitted) ?? "Unavailable"
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .voltlinePanel()
    }

    private func exposureMetric(_ label: String, duration: TimeInterval?, color: Color) -> some View {
        exposureValue(label, value: duration.map(durationValue) ?? "Unavailable", color: color)
    }

    private func exposureValue(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(VoltlineStyle.subdued)
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func estimateRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(VoltlineStyle.subdued)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    private var unavailableState: some View {
        ContentUnavailableView(
            model.lastError ?? "Waiting for health measurements",
            systemImage: "heart.text.clipboard"
        )
        .frame(maxWidth: .infinity, minHeight: 520)
        .voltlinePanel()
    }

    private func statusPill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(VoltlineStyle.mint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(VoltlineStyle.mint.opacity(0.1), in: Capsule())
    }

    private func reload() {
        let end = model.currentSnapshot?.timestamp ?? .now
        let start = selectedRange.startDate(reference: end, earliest: model.oldestMeasurement)
        healthSnapshots = model.healthSnapshots(from: start, through: end)
        exposure = HealthAnalytics.exposure(samples: model.powerSamples(from: start, through: end))
    }

    private func healthPercentage(_ electrical: BatteryElectricalTelemetry) -> String {
        HealthAnalytics.healthPercentage(
            fullChargeCapacity: electrical.fullChargeCapacityMilliampHours,
            designCapacity: electrical.designCapacityMilliampHours
        ).map { "\($0.formatted(.number.precision(.fractionLength(1))))%" } ?? "Unavailable"
    }

    private func capacity(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()).formatted()) mAh" } ?? "Unavailable"
    }

    private func value(_ value: Double?, unit: String, decimals: Int) -> String {
        value.map { "\($0.formatted(.number.precision(.fractionLength(decimals)))) \(unit)" } ?? "Unavailable"
    }

    private func batteryAge(_ manufactureDate: Date?, reference: Date) -> String {
        guard let age = HealthAnalytics.batteryAge(manufactureDate: manufactureDate, referenceDate: reference) else {
            return "Unavailable"
        }
        let years = age.year ?? 0
        let months = age.month ?? 0
        if years > 0 {
            return "\(years)y \(months)m"
        }
        return "\(months)m"
    }

    private func durationValue(_ duration: TimeInterval) -> String {
        if duration <= 0 {
            return "0m"
        }
        return duration.compactDuration
    }
}
