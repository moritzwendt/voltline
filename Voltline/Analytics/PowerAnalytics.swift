import Foundation

enum PowerGraphRange: String, CaseIterable, Identifiable, Sendable {
    case fifteenMinutes
    case oneHour
    case sixHours
    case twentyFourHours
    case sevenDays
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .fifteenMinutes: "15 min"
        case .oneHour: "1 hour"
        case .sixHours: "6 hours"
        case .twentyFourHours: "24 hours"
        case .sevenDays: "7 days"
        case .custom: "Custom"
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .fifteenMinutes: 15 * 60
        case .oneHour: 60 * 60
        case .sixHours: 6 * 60 * 60
        case .twentyFourHours: 24 * 60 * 60
        case .sevenDays: 7 * 24 * 60 * 60
        case .custom: nil
        }
    }
}

enum PowerGraphMetric: String, CaseIterable, Identifiable, Sendable {
    case systemPower
    case adapterPower
    case batteryPower
    case voltage
    case current
    case temperature

    var id: Self { self }

    var title: String {
        switch self {
        case .systemPower: "System power"
        case .adapterPower: "Adapter power"
        case .batteryPower: "Battery power"
        case .voltage: "Voltage"
        case .current: "Current"
        case .temperature: "Temperature"
        }
    }

    var unit: String {
        switch self {
        case .systemPower, .adapterPower, .batteryPower: "W"
        case .voltage: "V"
        case .current: "A"
        case .temperature: "°C"
        }
    }

    func value(in sample: BatterySamplePoint) -> Double? {
        switch self {
        case .systemPower: sample.electrical.systemPowerWatts
        case .adapterPower: sample.electrical.adapterPowerWatts
        case .batteryPower: sample.electrical.batteryPowerWatts
        case .voltage: sample.electrical.voltageVolts
        case .current: sample.electrical.amperageAmps
        case .temperature: sample.electrical.temperatureCelsius
        }
    }
}

enum PowerAnalytics {
    static func samples(
        _ samples: [BatterySamplePoint],
        from start: Date,
        through end: Date
    ) -> [BatterySamplePoint] {
        guard start <= end else {
            return []
        }
        return samples
            .filter { $0.timestamp >= start && $0.timestamp <= end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    static func measuredSamples(
        _ samples: [BatterySamplePoint],
        metric: PowerGraphMetric
    ) -> [BatterySamplePoint] {
        samples.filter { metric.value(in: $0) != nil }
    }

    static func displaySamples(
        _ samples: [BatterySamplePoint],
        metric: PowerGraphMetric,
        maxPoints: Int
    ) -> [BatterySamplePoint] {
        let measured = measuredSamples(samples, metric: metric)
        return BatteryAnalytics.downsample(samples: measured, maxPoints: maxPoints)
    }

    static func nearestOriginalSample(
        to date: Date,
        in samples: [BatterySamplePoint],
        metric: PowerGraphMetric
    ) -> BatterySamplePoint? {
        measuredSamples(samples, metric: metric).min { first, second in
            abs(first.timestamp.timeIntervalSince(date)) < abs(second.timestamp.timeIntervalSince(date))
        }
    }
}
