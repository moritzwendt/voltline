import Charts
import SwiftUI

struct HealthHistoryGrid: View {
    let snapshots: [DailyHealthSnapshotPoint]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 18)], spacing: 18) {
            HealthMetricChart(title: "Capacity history", metric: .capacity, snapshots: snapshots)
            HealthMetricChart(title: "Health history", metric: .health, snapshots: snapshots)
            HealthMetricChart(title: "Cycle history", metric: .cycles, snapshots: snapshots)
            HealthMetricChart(title: "Temperature history", metric: .temperature, snapshots: snapshots)
        }
    }
}

private enum HealthChartMetric: Equatable {
    case capacity
    case health
    case cycles
    case temperature

    var unit: String {
        switch self {
        case .capacity: "mAh"
        case .health: "%"
        case .cycles: ""
        case .temperature: "°C"
        }
    }

    func value(in snapshot: DailyHealthSnapshotPoint) -> Double? {
        switch self {
        case .capacity: snapshot.fullChargeCapacityMilliampHours
        case .health: snapshot.healthPercentage
        case .cycles: snapshot.cycleCount.map(Double.init)
        case .temperature: snapshot.temperatureCelsius
        }
    }

    var color: Color {
        switch self {
        case .capacity, .health: VoltlineStyle.mint
        case .cycles: VoltlineStyle.ice
        case .temperature: VoltlineStyle.amber
        }
    }
}

private struct HealthMetricChart: View {
    let title: String
    let metric: HealthChartMetric
    let snapshots: [DailyHealthSnapshotPoint]
    @State private var inspected: DailyHealthSnapshotPoint?
    @State private var inspectorTrailing = false

    private var measured: [DailyHealthSnapshotPoint] {
        snapshots.filter { metric.value(in: $0) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))
            if measured.isEmpty {
                ContentUnavailableView("No measurements", systemImage: "chart.xyaxis.line")
                    .frame(height: 210)
            } else {
                ZStack(alignment: inspectorTrailing ? .topTrailing : .topLeading) {
                    chart
                    if let inspected {
                        inspector(inspected)
                            .padding(7)
                    }
                }
                .frame(height: 210)
            }
        }
        .padding(22)
        .voltlinePanel()
    }

    private var chart: some View {
        Chart {
            if metric == .capacity {
                ForEach(measured) { snapshot in
                    if let design = snapshot.designCapacityMilliampHours {
                        LineMark(
                            x: .value("Day", snapshot.day),
                            y: .value("Design capacity", design),
                            series: .value("Capacity", "Design")
                        )
                        .foregroundStyle(VoltlineStyle.subdued)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    }
                }
            }
            ForEach(measured) { snapshot in
                if let measurement = metric.value(in: snapshot) {
                    LineMark(
                        x: .value("Day", snapshot.day),
                        y: .value(title, measurement),
                        series: .value("Measurement", title)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(metric.color)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    PointMark(
                        x: .value("Day point", snapshot.day),
                        y: .value("Measured point", measurement)
                    )
                    .foregroundStyle(measured.count == 1 ? metric.color : .clear)
                    .symbolSize(45)
                }
            }
            if let inspected, let measurement = metric.value(in: inspected) {
                RuleMark(x: .value("Inspected day", inspected.day))
                    .foregroundStyle(.white.opacity(0.32))
                PointMark(
                    x: .value("Selected day", inspected.day),
                    y: .value("Selected value", measurement)
                )
                .foregroundStyle(metric.color)
                .symbolSize(65)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(VoltlineStyle.hairline)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(VoltlineStyle.subdued)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(VoltlineStyle.hairline)
                AxisValueLabel {
                    if let measurement = value.as(Double.self) {
                        Text(axisValue(measurement))
                    }
                }
                .foregroundStyle(VoltlineStyle.subdued)
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(VoltlineStyle.canvas.opacity(0.32))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            inspected = nil
                            inspectorTrailing = false
                        }
                    }
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue("\(measured.count) daily measurements")
    }

    private func inspect(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let frameAnchor = proxy.plotFrame else {
            return
        }
        let frame = geometry[frameAnchor]
        let x = location.x - frame.origin.x
        guard x >= 0, x <= frame.width, let date = proxy.value(atX: x, as: Date.self) else {
            inspected = nil
            return
        }
        inspectorTrailing = location.x <= 210
        inspected = measured.min { first, second in
            abs(first.day.timeIntervalSince(date)) < abs(second.day.timeIntervalSince(date))
        }
    }

    private func inspector(_ snapshot: DailyHealthSnapshotPoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.day.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.semibold))
            Text(axisValue(metric.value(in: snapshot) ?? 0))
                .font(.headline)
                .monospacedDigit()
        }
        .padding(11)
        .frame(width: 170, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func axisValue(_ value: Double) -> String {
        let decimals = metric == .cycles ? 0 : 1
        let number = value.formatted(.number.precision(.fractionLength(decimals)))
        return metric.unit.isEmpty ? number : "\(number) \(metric.unit)"
    }
}
