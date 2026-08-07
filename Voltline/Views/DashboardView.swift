import SwiftUI

struct DashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Overview")
                .font(.largeTitle.weight(.semibold))

            ContentUnavailableView(
                "No measurements yet",
                systemImage: "battery.100percent"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(28)
        .background(VoltlineStyle.canvas)
    }
}

