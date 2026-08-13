import Foundation
import SwiftData

enum VoltlinePersistence {
    static func schema() -> Schema {
        Schema([
            BatterySampleRecord.self,
            PowerSessionRecord.self,
            DailySummaryRecord.self,
            DailyHealthSnapshotRecord.self
        ])
    }

    static func makeContainer() throws -> ModelContainer {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers/com.moritz.voltline/Data/Library/Application Support", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try makeContainer(at: directory.appending(path: "default.store"))
    }

    static func makeContainer(at url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let schema = schema()
        let configuration = ModelConfiguration(
            "Voltline history",
            schema: schema,
            url: url,
            allowsSave: allowsSave,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
