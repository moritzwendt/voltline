import Foundation

enum HealthHistoryRange: String, CaseIterable, Identifiable, Sendable {
    case thirtyDays
    case sixMonths
    case oneYear
    case allTime

    var id: Self { self }

    var title: String {
        switch self {
        case .thirtyDays: "30 days"
        case .sixMonths: "6 months"
        case .oneYear: "1 year"
        case .allTime: "All time"
        }
    }

    func startDate(reference: Date, earliest: Date?, calendar: Calendar = .current) -> Date {
        switch self {
        case .thirtyDays:
            calendar.date(byAdding: .day, value: -30, to: reference) ?? reference
        case .sixMonths:
            calendar.date(byAdding: .month, value: -6, to: reference) ?? reference
        case .oneYear:
            calendar.date(byAdding: .year, value: -1, to: reference) ?? reference
        case .allTime:
            earliest ?? Date.distantPast
        }
    }
}

struct HealthExposureMetrics: Sendable, Equatable {
    let measuredDuration: TimeInterval
    let aboveEightyDuration: TimeInterval?
    let belowTwentyDuration: TimeInterval?
    let aboveThirtyFiveDuration: TimeInterval?
    let atFullDuration: TimeInterval?
    let recommendedRangeDuration: TimeInterval?
    let equivalentFullCycles: Double?
}

struct CapacityTrendEstimate: Sendable, Equatable {
    let monthlyCapacityChangeMilliampHours: Double
    let estimatedHealthInSixMonths: Double
    let estimatedDateAtEightyPercent: Date?
}

enum HealthAnalytics {
    static func healthPercentage(fullChargeCapacity: Double?, designCapacity: Double?) -> Double? {
        guard let fullChargeCapacity, let designCapacity, fullChargeCapacity >= 0, designCapacity > 0 else {
            return nil
        }
        return fullChargeCapacity / designCapacity * 100
    }

    static func dailyRepresentatives(
        samples: [BatterySamplePoint],
        calendar: Calendar = .current
    ) -> [BatterySamplePoint] {
        let measured = samples.filter { sample in
            sample.electrical.fullChargeCapacityMilliampHours != nil ||
                sample.electrical.designCapacityMilliampHours != nil ||
                sample.electrical.cycleCount != nil ||
                sample.electrical.temperatureCelsius != nil
        }
        let grouped = Dictionary(grouping: measured) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.values.compactMap { daySamples in
            daySamples.max { $0.timestamp < $1.timestamp }
        }.sorted { $0.timestamp < $1.timestamp }
    }

    static func exposure(samples: [BatterySamplePoint], maximumInterval: TimeInterval = 600) -> HealthExposureMetrics {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        var measuredDuration: TimeInterval = 0
        var temperatureMeasuredDuration: TimeInterval = 0
        var aboveEighty: TimeInterval = 0
        var belowTwenty: TimeInterval = 0
        var aboveThirtyFive: TimeInterval = 0
        var atFull: TimeInterval = 0
        var recommended: TimeInterval = 0
        var dischargedPercentage = 0.0

        for pair in zip(ordered, ordered.dropFirst()) {
            let previous = pair.0
            let current = pair.1
            let interval = current.timestamp.timeIntervalSince(previous.timestamp)
            guard interval > 0, interval <= maximumInterval else {
                continue
            }
            measuredDuration += interval
            if previous.batteryLevel > 80 {
                aboveEighty += interval
            }
            if previous.batteryLevel < 20 {
                belowTwenty += interval
            }
            if previous.batteryLevel >= 99.5 {
                atFull += interval
            }
            if previous.batteryLevel >= 20, previous.batteryLevel <= 80 {
                recommended += interval
            }
            if let temperature = previous.electrical.temperatureCelsius {
                temperatureMeasuredDuration += interval
                if temperature > 35 {
                    aboveThirtyFive += interval
                }
            }
            let drop = previous.batteryLevel - current.batteryLevel
            if drop > 0 {
                dischargedPercentage += drop
            }
        }

        guard measuredDuration > 0 else {
            return HealthExposureMetrics(
                measuredDuration: 0,
                aboveEightyDuration: nil,
                belowTwentyDuration: nil,
                aboveThirtyFiveDuration: nil,
                atFullDuration: nil,
                recommendedRangeDuration: nil,
                equivalentFullCycles: nil
            )
        }
        return HealthExposureMetrics(
            measuredDuration: measuredDuration,
            aboveEightyDuration: aboveEighty,
            belowTwentyDuration: belowTwenty,
            aboveThirtyFiveDuration: temperatureMeasuredDuration > 0 ? aboveThirtyFive : nil,
            atFullDuration: atFull,
            recommendedRangeDuration: recommended,
            equivalentFullCycles: dischargedPercentage / 100
        )
    }

    static func capacityTrend(
        snapshots: [DailyHealthSnapshotPoint],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> CapacityTrendEstimate? {
        let measured = snapshots.compactMap { snapshot -> (Date, Double, Double)? in
            guard let full = snapshot.fullChargeCapacityMilliampHours,
                  let design = snapshot.designCapacityMilliampHours,
                  full > 0,
                  design > 0 else {
                return nil
            }
            return (snapshot.day, full, design)
        }.sorted { $0.0 < $1.0 }
        guard measured.count >= 7,
              let first = measured.first,
              let last = measured.last,
              last.0.timeIntervalSince(first.0) >= 14 * 24 * 60 * 60 else {
            return nil
        }

        let origin = first.0
        let x = measured.map { $0.0.timeIntervalSince(origin) / (24 * 60 * 60) }
        let y = measured.map { $0.1 }
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        let numerator = zip(x, y).reduce(0.0) { result, pair in
            result + (pair.0 - meanX) * (pair.1 - meanY)
        }
        let denominator = x.reduce(0.0) { result, value in
            result + pow(value - meanX, 2)
        }
        guard denominator > 0 else {
            return nil
        }
        let dailySlope = numerator / denominator
        let designCapacity = last.2
        let monthlyChange = dailySlope * 30.4375
        guard dailySlope < 0, abs(monthlyChange) <= designCapacity * 0.05 else {
            return nil
        }

        let estimatedCapacity = max(0, last.1 + dailySlope * 182.625)
        let estimatedHealth = estimatedCapacity / designCapacity * 100
        let targetCapacity = designCapacity * 0.8
        let daysToTarget = (targetCapacity - last.1) / dailySlope
        let targetDate: Date?
        if daysToTarget > 0, daysToTarget <= 3650 {
            targetDate = calendar.date(byAdding: .day, value: Int(daysToTarget.rounded()), to: referenceDate)
        } else {
            targetDate = nil
        }
        return CapacityTrendEstimate(
            monthlyCapacityChangeMilliampHours: monthlyChange,
            estimatedHealthInSixMonths: estimatedHealth,
            estimatedDateAtEightyPercent: targetDate
        )
    }

    static func batteryAge(
        manufactureDate: Date?,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> DateComponents? {
        guard let manufactureDate, manufactureDate <= referenceDate else {
            return nil
        }
        return calendar.dateComponents([.year, .month], from: manufactureDate, to: referenceDate)
    }
}
