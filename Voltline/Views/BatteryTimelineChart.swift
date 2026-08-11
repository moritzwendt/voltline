import Charts
import SwiftUI

struct BatteryTimelineChart: View {
    let samples: [BatterySamplePoint]
    @State private var inspectedSample: BatterySamplePoint?

    private var displaySamples: [BatterySamplePoint] {
        BatteryAnalytics.downsample(samples: samples, maxPoints: 720)
    }

    var body: some View {
        if displaySamples.count < 2 {
            ContentUnavailableView(
                "Two measurements are needed",
                systemImage: "waveform.path.ecg"
            )
        } else {
            VStack(spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    chart
                    if let inspectedSample {
                        ChartInspector(sample: inspectedSample)
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    }
                }
                ActivityRails(samples: displaySamples)
            }
            .animation(.smooth(duration: 0.18), value: inspectedSample?.id)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(displaySamples) { sample in
                AreaMark(
                    x: .value("Time", sample.timestamp),
                    yStart: .value("Base", 0),
                    yEnd: .value("Battery", sample.batteryLevel)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [VoltlineStyle.mint.opacity(0.22), VoltlineStyle.mint.opacity(0.015)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Battery", sample.batteryLevel)
                )
                .foregroundStyle(VoltlineStyle.mint)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                if sample.isCharging {
                    PointMark(
                        x: .value("Charge time", sample.timestamp),
                        y: .value("Charge level", sample.batteryLevel)
                    )
                    .foregroundStyle(VoltlineStyle.amber)
                    .symbolSize(22)
                }
            }

            if let inspectedSample {
                RuleMark(x: .value("Inspected time", inspectedSample.timestamp))
                    .foregroundStyle(.white.opacity(0.34))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Selected time", inspectedSample.timestamp),
                    y: .value("Selected level", inspectedSample.batteryLevel)
                )
                .foregroundStyle(VoltlineStyle.mint)
                .symbolSize(72)
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine().foregroundStyle(VoltlineStyle.hairline)
                AxisValueLabel(format: .dateTime.hour().minute())
                    .foregroundStyle(VoltlineStyle.subdued)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine().foregroundStyle(VoltlineStyle.hairline)
                AxisValueLabel {
                    if let level = value.as(Int.self) {
                        Text("\(level)%")
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
                        }
                    }
            }
        }
        .accessibilityLabel("Battery level over time")
        .accessibilityValue("\(displaySamples.count) recorded measurements")
    }

    private func inspect(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let frameAnchor = proxy.plotFrame else {
            return
        }
        let frame = geometry[frameAnchor]
        let x = location.x - frame.origin.x
        guard x >= 0, x <= frame.width, let date = proxy.value(atX: x, as: Date.self) else {
            inspectedSample = nil
            return
        }
        inspectedSample = displaySamples.min { first, second in
            abs(first.timestamp.timeIntervalSince(date)) < abs(second.timestamp.timeIntervalSince(date))
        }
    }
}

private struct ActivityRails: View {
    let samples: [BatterySamplePoint]

    var body: some View {
        VStack(spacing: 9) {
            rail(label: "Display", symbol: "display") { sample in
                sample.displayActive ? VoltlineStyle.ice : VoltlineStyle.raised
            }
            rail(label: "Power", symbol: "bolt.fill") { sample in
                sample.isCharging ? VoltlineStyle.amber : VoltlineStyle.raised
            }
            rail(label: "Low Power", symbol: "leaf.fill") { sample in
                sample.lowPowerModeEnabled ? VoltlineStyle.mint : VoltlineStyle.raised
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Display, charging, and Low Power Mode activity")
    }

    private func rail(label: String, symbol: String, color: @escaping (BatterySamplePoint) -> Color) -> some View {
        HStack(spacing: 10) {
            Label(label, systemImage: symbol)
                .font(.caption2.weight(.medium))
                .foregroundStyle(VoltlineStyle.subdued)
                .frame(width: 74, alignment: .leading)
            GeometryReader { geometry in
                let width = max(1, geometry.size.width / CGFloat(samples.count))
                ZStack(alignment: .leading) {
                    Capsule().fill(VoltlineStyle.raised)
                    ForEach(Array(samples.enumerated()), id: \.element.id) { index, sample in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color(sample))
                            .frame(width: width + 0.5, height: 6)
                            .offset(x: CGFloat(index) * width)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)
        }
    }
}

private struct ChartInspector: View {
    let sample: BatterySamplePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(sample.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.headline)
                .monospacedDigit()
            inspectorRow("Battery", value: "\(Int(sample.batteryLevel.rounded()))%")
            inspectorRow("Power", value: sample.chargingState.displayName)
            inspectorRow("System estimate", value: sample.systemEstimate.displayName)
            inspectorRow("Display", value: sample.displayActive ? "Active" : "Inactive")
            inspectorRow("Low Power Mode", value: sample.lowPowerModeEnabled ? "On" : "Off")
        }
        .padding(14)
        .frame(width: 210)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func inspectorRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(VoltlineStyle.subdued)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.caption)
    }
}
