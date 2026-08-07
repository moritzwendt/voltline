import SwiftUI

struct AppShellView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Overview", systemImage: "waveform.path.ecg")
            }
            .navigationSplitViewColumnWidth(220)
        } detail: {
            DashboardView()
                .frame(minWidth: 760, minHeight: 620)
        }
    }
}

