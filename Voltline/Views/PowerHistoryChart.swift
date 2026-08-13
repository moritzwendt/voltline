import Charts
import SwiftUI

struct PowerHistoryChart: View {
    let samples: [BatterySamplePoint]
    let metric: PowerGraphMetric
    @State private var inspectedSample: BatterySamplePoint?
    @State private var inspectorOnTrailingEdge = false

    private var displaySamples: [BatterySamplePoint] {
        PowerAnalytics.displaySamples(samples, metric: metric, maxPoints: 900)
    }

    private var segments: [PowerChartSegment] {
        PowerChartSegment.make(from: displaySamples, metric: metric)
    }

    var body: some View {
        if displaySamples.count < 2 {
            ContentUnavailableView(
                "Two measurements are needed",
                systemImage: "chart.xyaxis.line"
            )
        } else {
            ZStack(alignment: inspectorOnTrailingEdge ? .topTrailing : .topLeading) {
                chart
                if let inspectedSample {
                    PowerChartInspector(sample: inspectedSample, metric: metric)
                        .padding(8)
                        .transition(.opacity.combined(with: .scale(
                            scale: 0.96,
                            anchor: inspectorOnTrailingEdge ? .topTrailing : .topLeading
                        )))
                }
            }
            .animation(.smooth(duration: 0.16), value: inspectedSample?.id)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(segments) { segment in
                ForEach(segment.samples) { sample in
                    if let value = metric.value(in: sample) {
                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value(metric.title, value),
                            series: .value("Segment", segment.id)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(segment.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    }
                }
            }

            if let inspectedSample, let value = metric.value(in: inspectedSample) {
                RuleMark(x: .value("Inspected time", inspectedSample.timestamp))
                    .foregroundStyle(.white.opacity(0.34))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                PointMark(
                    x: .value("Selected time", inspectedSample.timestamp),
                    y: .value("Selected value", value)
                )
                .foregroundStyle(PowerChartSegment.color(for: inspectedSample, metric: metric))
                .symbolSize(70)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { value in
                AxisGridLine().foregroundStyle(VoltlineStyle.hairline)
                AxisValueLabel(format: .dateTime.hour().minute())
                    .foregroundStyle(VoltlineStyle.subdued)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(VoltlineStyle.hairline)
                AxisValueLabel {
                    if let measurement = value.as(Double.self) {
                        Text("\(measurement.formatted(.number.precision(.fractionLength(1)))) \(metric.unit)")
                    }
                }
                .foregroundStyle(VoltlineStyle.subdued)
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(VoltlineStyle.canvas.opacity(0.32))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case let .active(location):
                            inspect(location: location, proxy: proxy, geometry: geometry)
                        case .ended:
                            inspectedSample = nil
                            inspectorOnTrailingEdge = false
                        }
                    }
            }
        }
        .accessibilityLabel("\(metric.title) over time")
        .accessibilityValue("\(displaySamples.count) displayed measurements")
    }

    private func inspect(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let frameAnchor = proxy.plotFrame else {
            return
        }
        let frame = geometry[frameAnchor]
        let x = location.x - frame.origin.x
        guard x >= 0, x <= frame.width, let date = proxy.value(atX: x, as: Date.self) else {
            inspectedSample = nil
            inspectorOnTrailingEdge = false
            return
        }
        inspectorOnTrailingEdge = location.x <= 244
        inspectedSample = PowerAnalytics.nearestOriginalSample(to: date, in: samples, metric: metric)
    }
}

private struct PowerChartSegment: Identifiable {
    enum Role: Equatable {
        case mint
        case amber
        case ice
        case subdued
    }

    let id: String
    let role: Role
    let samples: [BatterySamplePoint]

    var color: Color {
        switch role {
        case .mint: VoltlineStyle.mint
        case .amber: VoltlineStyle.amber
        case .ice: VoltlineStyle.ice
        case .subdued: VoltlineStyle.subdued
        }
    }

    static func make(from samples: [BatterySamplePoint], metric: PowerGraphMetric) -> [PowerChartSegment] {
        guard let first = samples.first else {
            return []
        }
        var result: [PowerChartSegment] = []
        var currentRole = role(for: first, metric: metric)
        var currentSamples = [first]

        for sample in samples.dropFirst() {
            let nextRole = role(for: sample, metric: metric)
            if nextRole == currentRole {
                currentSamples.append(sample)
            } else {
                if currentSamples.count > 1 {
                    result.append(segment(samples: currentSamples, role: currentRole))
                }
                currentSamples = [currentSamples.last ?? sample, sample]
                currentRole = nextRole
            }
        }
        if currentSamples.count > 1 {
            result.append(segment(samples: currentSamples, role: currentRole))
        }
        return result
    }

    static func color(for sample: BatterySamplePoint, metric: PowerGraphMetric) -> Color {
        switch role(for: sample, metric: metric) {
        case .mint: VoltlineStyle.mint
        case .amber: VoltlineStyle.amber
        case .ice: VoltlineStyle.ice
        case .subdued: VoltlineStyle.subdued
        }
    }

    private static func role(for sample: BatterySamplePoint, metric: PowerGraphMetric) -> Role {
        switch metric {
        case .adapterPower, .voltage: .ice
        case .temperature: .amber
        case .systemPower: sample.powerSource == .battery ? .mint : .ice
        case .batteryPower, .current:
            if sample.chargingState == .charging {
                .amber
            } else if sample.powerSource == .battery {
                .mint
            } else {
                .subdued
            }
        }
    }

    private static func segment(samples: [BatterySamplePoint], role: Role) -> PowerChartSegment {
        PowerChartSegment(
            id: "\(samples.first?.id.uuidString ?? UUID().uuidString)|\(String(describing: role))",
            role: role,
            samples: samples
        )
    }
}

private struct PowerChartInspector: View {
    let sample: BatterySamplePoint
    let metric: PowerGraphMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(sample.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
                .monospacedDigit()
            inspectorRow(metric.title, value: value(metric.value(in: sample), unit: metric.unit))
            inspectorRow("System", value: value(sample.electrical.systemPowerWatts, unit: "W"))
            inspectorRow("Adapter", value: value(sample.electrical.adapterPowerWatts, unit: "W"))
            inspectorRow("Battery", value: value(sample.electrical.batteryPowerWatts, unit: "W"))
        }
        .padding(14)
        .frame(width: 220)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func inspectorRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(VoltlineStyle.subdued)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.caption)
    }

    private func value(_ value: Double?, unit: String) -> String {
        guard let value else {
            return "Unavailable"
        }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(unit)"
    }
}
