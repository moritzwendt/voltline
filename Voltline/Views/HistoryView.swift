import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    Text("History")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                    Spacer()
                    dayControls
                }

                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text(model.selectedDate.formatted(date: .complete, time: .omitted))
                            .font(.title2.weight(.semibold))
                        Text("\(model.samples.count) measurements")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(VoltlineStyle.subdued)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(VoltlineStyle.raised, in: Capsule())
                        Spacer()
                        if Calendar.current.isDateInToday(model.selectedDate) {
                            Label("Live", systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VoltlineStyle.mint)
                        }
                    }
                    if model.samples.isEmpty {
                        emptyHistory
                    } else {
                        BatteryTimelineChart(samples: model.samples)
                            .frame(height: 430)
                    }
                }
                .padding(26)
                .voltlinePanel()

                dailyMetrics
            }
            .padding(32)
            .frame(maxWidth: 1320, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private var dayControls: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    moveDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 30)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Previous day")

                DatePicker("History date", selection: Binding(
                    get: { model.selectedDate },
                    set: { model.selectDate($0) }
                ), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .padding(.horizontal, 10)
                .frame(height: 42)
                .glassEffect(.regular.interactive(), in: Capsule())

                if !model.recordedDays.isEmpty {
                    Menu {
                        ForEach(model.recordedDays) { day in
                            Button(recordedDayTitle(day)) {
                                model.selectDate(day.date)
                            }
                        }
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .frame(width: 28, height: 30)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Recorded days")
                }

                Button {
                    moveDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 28, height: 30)
                }
                .buttonStyle(.glass)
                .disabled(Calendar.current.isDateInToday(model.selectedDate))
                .accessibilityLabel("Next day")
            }
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(VoltlineStyle.ice)
            Text("No measurements")
                .font(.title3.weight(.semibold))
            if let latest = model.latestRecordedDate,
               !Calendar.current.isDate(latest, inSameDayAs: model.selectedDate) {
                Button("Latest recorded day") {
                    model.selectLatestRecordedDay()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 430)
    }

    private var dailyMetrics: some View {
        HStack(spacing: 14) {
            historyMetric("Used", value: String(format: "%.0f%%", model.dayMetrics.batteryUsed), color: VoltlineStyle.mint)
            historyMetric("On battery", value: model.dayMetrics.timeOnBattery.compactDuration, color: VoltlineStyle.ice)
            historyMetric("Display active", value: model.dayMetrics.activeTime.compactDuration, color: VoltlineStyle.amber)
            historyMetric("Average drain", value: model.dayMetrics.averageDrainRate.map { String(format: "%.1f%%/h", $0) } ?? "Learning", color: VoltlineStyle.alert)
        }
    }

    private func historyMetric(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label).foregroundStyle(VoltlineStyle.subdued)
            }
            Text(value)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .voltlinePanel(cornerRadius: 20)
    }

    private func moveDay(by offset: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: model.selectedDate) else {
            return
        }
        model.selectDate(date)
    }

    private func recordedDayTitle(_ day: RecordedDay) -> String {
        let date = day.date.formatted(date: .abbreviated, time: .omitted)
        let count = day.measurementCount == 1 ? "1 measurement" : "\(day.measurementCount.formatted()) measurements"
        return "\(date), \(count)"
    }
}
