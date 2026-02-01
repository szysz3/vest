import SwiftUI

public enum VestTone: String, Sendable {
    case electric
    case mint
    case sunset
    case violet
    case ocean
    case sand

    public var color: Color {
        switch self {
        case .electric:
            return Color(red: 0.44, green: 0.70, blue: 1.00)
        case .mint:
            return Color(red: 0.37, green: 0.86, blue: 0.74)
        case .sunset:
            return Color(red: 1.00, green: 0.62, blue: 0.43)
        case .violet:
            return Color(red: 0.70, green: 0.56, blue: 1.00)
        case .ocean:
            return Color(red: 0.33, green: 0.61, blue: 0.94)
        case .sand:
            return Color(red: 0.95, green: 0.83, blue: 0.58)
        }
    }
}

enum VestActionColor {
    static let positive = Color(red: 0.37, green: 0.86, blue: 0.74)
    static let negative = Color(red: 1.00, green: 0.62, blue: 0.43)
}
