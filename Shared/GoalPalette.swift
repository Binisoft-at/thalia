import SwiftUI

// v4 design: every annual goal has its own colour, used for chips, category heads, goal tiles
// and bars – so a category is recognisable at a glance, in the app, the PDF and the widgets (R83).
// Compiled into the apps and both widget extensions: SwiftUI only.

enum GoalPalette {
    static let colors: [Color] = [
        Color(red: 0.93, green: 0.42, blue: 0.33),  // 1 – coral
        Color(red: 0.55, green: 0.38, blue: 0.86),  // 2 – violet
        Color(red: 0.05, green: 0.55, blue: 0.60),  // 3 – teal
        Color(red: 0.30, green: 0.36, blue: 0.80),  // 4 – indigo
        Color(red: 0.88, green: 0.62, blue: 0.12),  // 5 – amber
        Color(red: 0.90, green: 0.36, blue: 0.58),  // 6 – pink
        Color(red: 0.36, green: 0.52, blue: 0.62),  // 7 – slate
        Color(red: 0.20, green: 0.62, blue: 0.36),  // 8 – green
        Color(red: 0.95, green: 0.50, blue: 0.18),  // 9 – orange
        Color(red: 0.76, green: 0.28, blue: 0.44),  // 10 – raspberry
    ]

    static func color(goal key: String) -> Color {
        let number = Int(key.split(separator: ".").first.map(String.init) ?? key) ?? 1
        return colors[(max(1, number) - 1) % colors.count]
    }

    /// The colour of a category is its goal's colour.
    static func color(category key: String) -> Color { color(goal: key) }

    /// A two-tone gradient for heads in a goal's colour – opaque (R44): the second tone is the goal
    /// colour a little darker instead of see-through, so white text on it doesn't lose contrast.
    static func gradient(goal key: String) -> LinearGradient {
        let base = color(goal: key)
        let deeper = base.mix(with: .black, by: 0.18)
        return LinearGradient(colors: [base, deeper], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
