import SwiftUI

// MacKit's visual language, in one place.
//
// The app should feel like part of macOS, only more considered:
//
// 1. Native controls. Switches and pop-up menus are the system's own, so
//    they look and behave the way every other Mac app has taught people.
// 2. Plain language first. A setting is described in a sentence. Keys and
//    commands exist for people who want them, one click away, never in view
//    by default.
// 3. One calm surface. Settings sit in grouped cards on the window
//    background. Glass is reserved for the one control that floats.

/// The 4pt spacing scale.
enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum Radius {
    /// Small inline elements, such as a code line.
    static let small: CGFloat = 6
    /// Sidebar rows and buttons.
    static let control: CGFloat = 8
    /// Grouped cards.
    static let card: CGFloat = 12
}

enum Layout {
    /// The widest a page gets. Past this a switch drifts too far from its
    /// label to read as one row.
    static let contentWidth: CGFloat = 640
    static let pageInset: CGFloat = Space.xxl
    /// Horizontal padding inside a card.
    static let cardInset: CGFloat = 14
}

enum Motion {
    /// Press feedback. Fast, with a strong ease-out so it reads as instant.
    static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
    /// Small state changes: a mark appearing, a hover.
    static let state = Animation.spring(response: 0.26, dampingFraction: 1)
    /// A row opening, a surface arriving.
    static let surface = Animation.spring(response: 0.34, dampingFraction: 0.9)
    /// Used in place of movement when Reduce Motion is on.
    static let fade = Animation.easeOut(duration: 0.15)
}

/// The type scale. Sizes follow the macOS text styles.
enum TextRole {
    /// The name of this Mac on the home screen.
    case hero
    /// A page title.
    case title
    /// A heading above a group of settings, or in a sheet.
    case heading
    /// The name of a setting.
    case label
    /// The sentence under a setting's name.
    case detail
    case body
    /// The only monospaced role. Used for keys and commands, on request.
    case code

    var font: Font {
        switch self {
        case .hero: .system(size: 30, weight: .bold)
        case .title: .system(size: 24, weight: .bold)
        case .heading: .system(size: 13, weight: .semibold)
        case .label: .system(size: 13)
        case .detail: .system(size: 11.5)
        case .body: .system(size: 13)
        case .code: .system(size: 11, design: .monospaced)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .hero: -0.6
        case .title: -0.4
        default: 0
        }
    }
}

extension View {
    /// Applies a role from MacKit's type scale.
    func text(_ role: TextRole) -> some View {
        font(role.font).tracking(role.tracking)
    }
}

extension ShapeStyle where Self == Color {
    /// The fill of a grouped card.
    static var card: Color { Color.primary.opacity(0.045) }
    static var cardBorder: Color { Color.primary.opacity(0.06) }
    static var rowHover: Color { Color.primary.opacity(0.035) }
}
