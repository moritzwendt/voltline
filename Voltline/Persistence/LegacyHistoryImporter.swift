import Foundation
import SwiftData

struct HistoryImportResult: Equatable {
    let measurements: Int
    let sessions: Int
    let summaries: Int
    let healthSnapshots: Int
}

@MainActor
enum LegacyHistoryImporter {
    static func importStore(at url: URL, into destination: ModelContext) throws -> HistoryImportResult {
        let stagedDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: stagedDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: stagedDirectory)
        }

        let stagedURL = stagedDirectory.appending(path: "history.store")
        try FileManager.default.copyItem(at: url, to: stagedURL)
        copyCompanionFile(from: url, to: stagedURL, suffix: "-wal")
        copyCompanionFile(from: url, to: stagedURL, suffix: "-shm")

        let sourceContainer = try VoltlinePersistence.makeContainer(at: stagedURL, allowsSave: false)
        let source = ModelContext(sourceContainer)

        let existingMeasurements = try destination.fetch(FetchDescriptor<BatterySampleRecord>())
        var measurementIDs = Set(existingMeasurements.map(\.id))
        var measurementFingerprints = Set(existingMeasurements.map(MeasurementFingerprint.init))
        var importedMeasurements = 0

        for record in try source.fetch(FetchDescriptor<BatterySampleRecord>()) {
            let fingerprint = MeasurementFingerprint(record)
            guard !measurementIDs.contains(record.id), !measurementFingerprints.contains(fingerprint) else {
                continue
            }
            destination.insert(BatterySampleRecord(copying: record))
            measurementIDs.insert(record.id)
            measurementFingerprints.insert(fingerprint)
            importedMeasurements += 1
        }

        let existingSessions = try destination.fetch(FetchDescriptor<PowerSessionRecord>())
        var sessionIDs = Set(existingSessions.map(\.id))
        var importedSessions = 0

        for record in try source.fetch(FetchDescriptor<PowerSessionRecord>()) where !sessionIDs.contains(record.id) {
            destination.insert(PowerSessionRecord(copying: record))
            sessionIDs.insert(record.id)
            importedSessions += 1
        }

        let existingSummaries = try destination.fetch(FetchDescriptor<DailySummaryRecord>())
        var summaryDays = Set(existingSummaries.map(\.day))
        var importedSummaries = 0

        for record in try source.fetch(FetchDescriptor<DailySummaryRecord>()) where !summaryDays.contains(record.day) {
            destination.insert(DailySummaryRecord(copying: record))
            summaryDays.insert(record.day)
            importedSummaries += 1
        }

        let existingHealth = try destination.fetch(FetchDescriptor<DailyHealthSnapshotRecord>())
        var healthDays = Set(existingHealth.map(\.day))
        var importedHealth = 0

        for record in try source.fetch(FetchDescriptor<DailyHealthSnapshotRecord>()) where !healthDays.contains(record.day) {
            destination.insert(DailyHealthSnapshotRecord(copying: record))
            healthDays.insert(record.day)
            importedHealth += 1
        }

        try destination.save()
        return HistoryImportResult(
            measurements: importedMeasurements,
            sessions: importedSessions,
            summaries: importedSummaries,
            healthSnapshots: importedHealth
        )
    }

    private static func copyCompanionFile(from source: URL, to destination: URL, suffix: String) {
        let sourceFile = URL(fileURLWithPath: source.path + suffix)
        guard FileManager.default.fileExists(atPath: sourceFile.path) else {
            return
        }
        let destinationFile = URL(fileURLWithPath: destination.path + suffix)
        try? FileManager.default.copyItem(at: sourceFile, to: destinationFile)
    }
}

private struct MeasurementFingerprint: Hashable {
    let timestamp: Date
    let batteryLevel: Int
    let powerSource: String
    let chargingState: String

    init(_ record: BatterySampleRecord) {
        timestamp = record.timestamp
        batteryLevel = Int((record.batteryLevel * 1_000).rounded())
        powerSource = record.powerSourceRaw
        chargingState = record.chargingStateRaw
    }
}
