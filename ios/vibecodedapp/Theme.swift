import SwiftUI
import UIKit

// Palette sampled from the supplied dark agenda and drawer references.
enum SchoolTheme {
    static let blue = Color(red: 0.02, green: 0.57, blue: 0.96)
    static let navy = Color(red: 0.02, green: 0.16, blue: 0.28)
    static let week = Color(red: 0.03, green: 0.20, blue: 0.34)
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
            : UIColor.systemBackground
    })
    static let footer = Color(red: 0.0, green: 0.08, blue: 0.12)
    static let paleBlue = navy
    static let ink = Color.primary
    static let orange = Color(red: 1.0, green: 0.51, blue: 0.0)
    static let divider = Color.primary.opacity(0.38)
    static let homework = Color(red: 0.0, green: 0.78, blue: 0.66)
}
