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
                VStack(alignment: .leading, spacing: 10) {
                    Text(snapshot.percentage.formatted(.number.precision(.fractionLength(0))) + "%")
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                    Text(snapshot.isCharging ? "Charging" : "On battery")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
