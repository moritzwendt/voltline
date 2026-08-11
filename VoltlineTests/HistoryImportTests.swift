import Foundation
import SwiftData
import Testing
@testable import Voltline

struct HistoryImportTests {
    @Test @MainActor
    func importingTheSameStoreTwiceDoesNotDuplicateMeasurements() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let sourceURL = directory.appending(path: "source.store")
        let destinationURL = directory.appending(path: "destination.store")

        do {
            let sourceContainer = try VoltlinePersistence.makeContainer(at: sourceURL)
            let source = ModelContext(sourceContainer)
            let sessionID = UUID()
            let start = Date(timeIntervalSince1970: 1_800_000_000)
            source.insert(BatterySampleRecord(snapshot: snapshot(at: start, level: 82), sessionID: sessionID))
            source.insert(BatterySampleRecord(snapshot: snapshot(at: start.addingTimeInterval(45), level: 81), sessionID: sessionID))
            try source.save()
        }

        let destinationContainer = try VoltlinePersistence.makeContainer(at: destinationURL)
        let destination = ModelContext(destinationContainer)
        let first = try LegacyHistoryImporter.importStore(at: sourceURL, into: destination)
        let second = try LegacyHistoryImporter.importStore(at: sourceURL, into: destination)

        #expect(first.measurements == 2)
        #expect(second.measurements == 0)
        #expect(try destination.fetchCount(FetchDescriptor<BatterySampleRecord>()) == 2)
    }

    private func snapshot(at date: Date, level: Double) -> BatterySnapshot {
        BatterySnapshot(
            timestamp: date,
            percentage: level,
            powerSource: .battery,
            chargingState: .discharging,
            systemTimeRemaining: .unavailable,
            timeUntilFull: .unavailable,
            lowPowerModeEnabled: false,
            displayActive: true,
            systemSleeping: false,
            warningState: .unavailable
        )
    }
}
