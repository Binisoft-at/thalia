import SwiftUI
import BinisoftKit
import ThaliaCore

// v4 design: every annual goal has its own colour, used for chips, category heads, goal tiles
// and bars – so a category is recognisable at a glance, in the app and in the PDF.

enum GoalPalette {
    static let colors: [Color] = [
        Color(red: 0.93, green: 0.42, blue: 0.33),  // 1 Fit Body – coral
        Color(red: 0.55, green: 0.38, blue: 0.86),  // 2 Strong Mind – violet
        Color(red: 0.05, green: 0.55, blue: 0.60),  // 3 Business – teal
        Color(red: 0.30, green: 0.36, blue: 0.80),  // 4 Schlaf – indigo
        Color(red: 0.88, green: 0.62, blue: 0.12),  // 5 Bücher – amber
        Color(red: 0.90, green: 0.36, blue: 0.58),  // 6 Menschen – pink
        Color(red: 0.36, green: 0.52, blue: 0.62),  // 7 Rauchstopp – slate
        Color(red: 0.20, green: 0.62, blue: 0.36),  // 8 Vermögen – green
        Color(red: 0.95, green: 0.50, blue: 0.18),  // 9 Hobby – orange
        Color(red: 0.76, green: 0.28, blue: 0.44),  // 10 Familie – raspberry
    ]

    static func color(goal key: String) -> Color {
        let number = Int(key.split(separator: ".").first.map(String.init) ?? key) ?? 1
        return colors[(max(1, number) - 1) % colors.count]
    }

    /// The colour of a category is its goal's colour.
    static func color(category key: String) -> Color { color(goal: key) }

    /// A two-tone gradient for heads in a goal's colour.
    static func gradient(goal key: String) -> LinearGradient {
        let base = color(goal: key)
        return LinearGradient(colors: [base, base.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension TrackCategory {
    var color: Color { GoalPalette.color(category: key) }

    /// "Ernährung und Gewicht" → "Ernährung", "Morgenroutine und Fokus" → "Morgenroutine".
    var shortTitle: String {
        let first = title.split(whereSeparator: { $0 == " " || $0 == "&" || $0 == "/" }).first.map(String.init) ?? title
        return first.count > 13 ? String(first.prefix(12)) + "." : first
    }
}

extension AnnualGoal {
    var color: Color { GoalPalette.color(goal: key) }
}

/// A rounded card on the screen background, optionally with a coloured edge.
struct SurfaceCard: ViewModifier {
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .leading) {
                if let tint {
                    UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, style: .continuous)
                        .fill(tint)
                        .frame(width: 5)
                }
            }
    }
}

extension View {
    func surfaceCard(tint: Color? = nil) -> some View { modifier(SurfaceCard(tint: tint)) }
}
