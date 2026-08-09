import SwiftUI

enum VoltlineStyle {
    static let canvas = Color(red: 0.035, green: 0.045, blue: 0.052)
    static let sidebar = Color(red: 0.050, green: 0.061, blue: 0.069)
    static let surface = Color(red: 0.075, green: 0.088, blue: 0.096)
    static let raised = Color(red: 0.098, green: 0.114, blue: 0.122)
    static let mint = Color(red: 0.31, green: 0.91, blue: 0.71)
    static let amber = Color(red: 1.00, green: 0.69, blue: 0.30)
    static let ice = Color(red: 0.39, green: 0.75, blue: 1.00)
    static let alert = Color(red: 1.00, green: 0.40, blue: 0.42)
    static let subdued = Color.white.opacity(0.56)
    static let hairline = Color.white.opacity(0.075)
}

extension View {
    func voltlinePanel(cornerRadius: CGFloat = 26) -> some View {
        self
            .background(VoltlineStyle.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(VoltlineStyle.hairline)
            }
    }
}

extension TimeInterval {
    var compactDuration: String {
        guard self.isFinite, self > 0 else {
            return "Unavailable"
        }
        let totalMinutes = Int(self / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

