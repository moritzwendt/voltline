import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Overview")
                    .font(.largeTitle.weight(.semibold))

                Spacer()

                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.refresh()
                }
            }

            if let snapshot = model.currentSnapshot {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(snapshot.percentage.formatted(.number.precision(.fractionLength(0))) + "%")
                            .font(.system(size: 64, weight: .semibold, design: .rounded))
                        Text(snapshot.isCharging ? "Charging" : "On battery")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Power source")
                            .foregroundStyle(.secondary)
                        Text(snapshot.powerSource == .battery ? "Battery" : "Power adapter")
                            .font(.title2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(24)
                .background(VoltlineStyle.raised, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 16) {
                    Text("Battery timeline")
                        .font(.title2.weight(.semibold))
                    BatteryTimelineChart(samples: model.samples)
                        .frame(minHeight: 300)
                }
                .padding(24)
                .background(VoltlineStyle.raised, in: RoundedRectangle(cornerRadius: 20))
            } else {
                ContentUnavailableView(
                    "Battery unavailable",
                    systemImage: "battery.0percent"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(28)
        .background(VoltlineStyle.canvas)
    }
}
