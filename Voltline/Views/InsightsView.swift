import SwiftUI

struct InsightsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Insights")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))

                if model.samples.count < 12 {
                    ContentUnavailableView(
                        "Insights appear after enough history is recorded",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity, minHeight: 430)
                    .voltlinePanel()
                } else {
                    insightGrid
                }
            }
            .padding(32)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private var insightGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
            InsightCard(
                symbol: "gauge.with.dots.needle.67percent",
                color: VoltlineStyle.mint,
                title: drainTitle
            )
            InsightCard(
                symbol: "display",
                color: VoltlineStyle.ice,
                title: activeTitle
            )
            InsightCard(
                symbol: "bolt.fill",
                color: VoltlineStyle.amber,
                title: sessionTitle
            )
        }
    }

    private var drainTitle: String {
        guard let rate = model.dayMetrics.averageDrainRate else {
            return "Voltline is still learning today’s drain pace."
        }
        return "Average battery drain today is \(String(format: "%.1f", abs(rate))) percent per hour."
    }

    private var activeTitle: String {
        let percent = model.dayMetrics.timeOnBattery > 0 ? model.dayMetrics.activeTime / model.dayMetrics.timeOnBattery * 100 : 0
        return "The display was active for \(Int(percent.rounded())) percent of measured battery time."
    }

    private var sessionTitle: String {
        "Voltline found \(model.dayMetrics.sessionCount) discharge \(model.dayMetrics.sessionCount == 1 ? "session" : "sessions") today."
    }
}

private struct InsightCard: View {
    let symbol: String
    let color: Color
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            Text(title)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .voltlinePanel()
    }
}
