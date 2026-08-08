import SwiftUI

struct AppShellView: View {
    private enum Destination: String, Hashable, CaseIterable {
        case overview = "Overview"
        case history = "History"

        var symbol: String {
            switch self {
            case .overview: "waveform.path.ecg"
            case .history: "clock.arrow.trianglehead.counterclockwise.rotate.90"
            }
        }
    }

    @State private var selection = Destination.overview

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, id: \.self, selection: $selection) { destination in
                Label(destination.rawValue, systemImage: destination.symbol)
            }
            .navigationSplitViewColumnWidth(220)
        } detail: {
            Group {
                switch selection {
                case .overview: DashboardView()
                case .history: HistoryView()
                }
            }
            .frame(minWidth: 760, minHeight: 620)
        }
    }
}
