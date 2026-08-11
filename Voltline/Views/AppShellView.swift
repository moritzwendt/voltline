import AppKit
import SwiftUI

struct AppShellView: View {
    enum Destination: String, CaseIterable, Hashable, Identifiable {
        case overview = "Overview"
        case history = "History"
        case insights = "Insights"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .overview: "waveform.path.ecg"
            case .history: "clock.arrow.trianglehead.counterclockwise.rotate.90"
            case .insights: "sparkles"
            }
        }
    }

    @State private var selection: Destination? = .overview

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                brand
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 16)

                List(Destination.allCases, selection: $selection) { destination in
                    NavigationLink(value: destination) {
                        Label(destination.rawValue, systemImage: destination.symbol)
                            .font(.system(size: 15, weight: .medium))
                            .padding(.vertical, 7)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

                Spacer()

                LiveStatusView()
                    .padding(16)
            }
            .background(VoltlineStyle.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 226, max: 250)
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview:
                    DashboardView()
                case .history:
                    HistoryView()
                case .insights:
                    InsightsView()
                }
            }
            .frame(minWidth: 760, minHeight: 620)
            .background(VoltlineStyle.canvas)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
    }

    private var brand: some View {
        HStack(spacing: 11) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)

            Text("Voltline")
                .font(.system(size: 17, weight: .semibold))
        }
    }
}

private struct LiveStatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.monitoringEnabled ? VoltlineStyle.mint : VoltlineStyle.subdued)
                .frame(width: 7, height: 7)
                .shadow(color: model.monitoringEnabled ? VoltlineStyle.mint.opacity(0.6) : .clear, radius: 5)
            Text(status)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(VoltlineStyle.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var status: String {
        guard model.monitoringEnabled else {
            return "Monitoring paused"
        }
        guard let lastUpdated = model.lastUpdated else {
            return "Monitoring"
        }
        return "Monitoring, updated \(lastUpdated.formatted(.relative(presentation: .named)))"
    }
}
