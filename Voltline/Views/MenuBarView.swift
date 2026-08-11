import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Voltline")
                .font(.headline)

            if let snapshot = model.currentSnapshot {
                HStack {
                    Image(systemName: snapshot.isCharging ? "battery.100percent.bolt" : "battery.100percent")
                    Text(snapshot.percentage.formatted(.number.precision(.fractionLength(0))) + "%")
                        .font(.title2.weight(.semibold))
                }
            }

            ForEach(model.visibleAccessories) { device in
                HStack {
                    Text(device.name)
                    Spacer()
                    Text("\(device.level)%")
                }
            }

            Divider()

            Button("Open Voltline") {
                NSApp.activate()
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 240)
    }
}
