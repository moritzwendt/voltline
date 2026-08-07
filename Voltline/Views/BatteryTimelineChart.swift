import Charts
import SwiftUI

struct BatteryTimelineChart: View {
    let samples: [BatterySamplePoint]

    var body: some View {
        Chart(samples) { sample in
            AreaMark(
                x: .value("Time", sample.timestamp),
                y: .value("Battery", sample.batteryLevel)
            )
            .foregroundStyle(VoltlineStyle.mint.opacity(0.18))

            LineMark(
                x: .value("Time", sample.timestamp),
                y: .value("Battery", sample.batteryLevel)
            )
            .foregroundStyle(VoltlineStyle.mint)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .chartYScale(domain: 0 ... 100)
    }
}

