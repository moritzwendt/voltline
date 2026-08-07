import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var lastUpdated: Date?
}
