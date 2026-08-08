import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("History")
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                DatePicker("Day", selection: selectedDate, displayedComponents: .date)
                    .labelsHidden()
            }

            BatteryTimelineChart(samples: model.samplesForSelectedDay)
                .frame(minHeight: 360)
                .padding(22)
                .background(VoltlineStyle.raised, in: RoundedRectangle(cornerRadius: 20))

            HStack {
                Text("Battery used")
                Spacer()
                Text(model.dayMetrics.batteryUsed.formatted(.number.precision(.fractionLength(1))) + "%")
                    .font(.title2.weight(.semibold))
            }
            .padding(20)
            .background(VoltlineStyle.raised, in: RoundedRectangle(cornerRadius: 20))
        }
        .padding(28)
        .background(VoltlineStyle.canvas)
    }

    private var selectedDate: Binding<Date> {
        Binding(
            get: { model.selectedDate },
            set: { model.selectDate($0) }
        )
    }
}

