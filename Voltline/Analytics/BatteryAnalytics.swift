import Foundation

struct BatteryDayMetrics: Sendable, Equatable {
    let batteryUsed: Double
    let timeOnBattery: TimeInterval
    let activeTime: TimeInterval
    let averageDrainRate: Double?
    let chargingTime: TimeInterval
    let sessionCount: Int
}

enum BatteryAnalytics {
    static func downsample(samples: [BatterySamplePoint], maxPoints: Int) -> [BatterySamplePoint] {
        guard samples.count > maxPoints, maxPoints > 2 else {
            return samples
        }
        let strideSize = Int(ceil(Double(samples.count) / Double(maxPoints)))
        var result: [BatterySamplePoint] = []
        for index in samples.indices where index % strideSize == 0 {
            result.append(samples[index])
        }
        if result.last?.id != samples.last?.id, let last = samples.last {
            result.append(last)
        }
        return result
    }

    static func dischargeRate(
        samples: [BatterySamplePoint],
        window: TimeInterval,
        referenceDate: Date? = nil
    ) -> Double? {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        guard let end = referenceDate ?? ordered.last?.timestamp else {
            return nil
        }
        let start = end.addingTimeInterval(0 - window)
        let candidates = ordered.filter {
            $0.timestamp >= start && $0.timestamp <= end && $0.powerSource == .battery && !$0.isCharging && !$0.systemSleeping
        }
        guard candidates.count >= 2 else {
            return nil
        }
        let origin = candidates[0].timestamp
        let x = candidates.map { $0.timestamp.timeIntervalSince(origin) / 3600 }
        let y = candidates.map(\.batteryLevel)
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        let numerator = zip(x, y).reduce(0.0) { partial, pair in
            partial + (pair.0 - meanX) * (pair.1 - meanY)
        }
        let denominator = x.reduce(0.0) { partial, value in
            partial + pow(value - meanX, 2)
        }
        guard denominator > 0 else {
            return nil
        }
        let rate = numerator / denominator
        return rate <= 0.5 ? rate : nil
    }

    static func derivedRuntime(level: Double, rate: Double?) -> TimeInterval? {
        guard let rate, rate < 0 else {
            return nil
        }
        return level / abs(rate) * 3600
    }

    static func dayMetrics(samples: [BatterySamplePoint]) -> BatteryDayMetrics {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        var used = 0.0
        var batteryTime: TimeInterval = 0
        var activeTime: TimeInterval = 0
        var chargingTime: TimeInterval = 0
        var sessions = Set<UUID>()

        for pair in zip(ordered, ordered.dropFirst()) {
            let previous = pair.0
            let current = pair.1
            let interval = current.timestamp.timeIntervalSince(previous.timestamp)
            guard interval > 0, interval <= 600, previous.sessionID == current.sessionID else {
                continue
            }
            if previous.powerSource == .battery && !previous.isCharging && !previous.systemSleeping {
                batteryTime += interval
                sessions.insert(previous.sessionID)
                if previous.displayActive {
                    activeTime += interval
                }
                let drop = previous.batteryLevel - current.batteryLevel
                if drop > 0 {
                    used += drop
                }
            }
            if previous.isCharging {
                chargingTime += interval
            }
        }

        let average = batteryTime > 0 ? 0 - used / (batteryTime / 3600) : nil
        return BatteryDayMetrics(
            batteryUsed: used,
            timeOnBattery: batteryTime,
            activeTime: activeTime,
            averageDrainRate: average,
            chargingTime: chargingTime,
            sessionCount: sessions.count
        )
    }
}
