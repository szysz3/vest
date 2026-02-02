import SwiftUI

public enum VestTone: String, Sendable {
    /// Positive action (buy, deposit)
    case mint
    /// Negative action (sell, withdrawal)
    case sunset

    // Asset types – evenly spaced hues, consistent saturation & lightness
    case electric   // stocks  – cornflower blue  ~225°
    case ocean      // ETF     – soft cyan        ~195°
    case violet     // crypto  – lavender         ~275°
    case amber      // gold    – warm gold        ~45°
    case rose       // bonds   – dusty pink       ~335°
    case sage       // cash    – yellow-green     ~90°

    public var color: Color {
        switch self {
        case .mint:
            return Color(red: 0.40, green: 0.78, blue: 0.68)
        case .sunset:
            return Color(red: 0.90, green: 0.55, blue: 0.48)
        case .electric:
            return Color(red: 0.47, green: 0.63, blue: 0.90)
        case .ocean:
            return Color(red: 0.42, green: 0.72, blue: 0.82)
        case .violet:
            return Color(red: 0.66, green: 0.55, blue: 0.87)
        case .amber:
            return Color(red: 0.85, green: 0.72, blue: 0.42)
        case .rose:
            return Color(red: 0.84, green: 0.56, blue: 0.62)
        case .sage:
            return Color(red: 0.62, green: 0.78, blue: 0.48)
        }
    }
}

enum VestActionColor {
    static let positive = Color(red: 0.40, green: 0.78, blue: 0.68)
    static let negative = Color(red: 0.90, green: 0.55, blue: 0.48)
}
