import Foundation
import SwiftData

struct HistoryImportResult: Equatable {
    let measurements: Int
    let sessions: Int
    let summaries: Int
}

@MainActor
enum LegacyHistoryImporter {
    static func importStore(at url: URL, into destination: ModelContext) throws -> HistoryImportResult {
        HistoryImportResult(measurements: 0, sessions: 0, summaries: 0)
    }
}

