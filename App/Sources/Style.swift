import SwiftUI
import BinisoftKit
import ThaliaCore

// The goal colours themselves live in Shared/GoalPalette.swift (also compiled into the widgets, R83).

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

    /// R44: the kit's primary action (`primaryActionStyle`), filled with `accentFill` so its white
    /// text stays readable in dark mode. Light mode looks exactly as before.
    func thaliaPrimaryAction() -> some View {
        self.buttonStyle(.glassProminent).tint(Color.accentFill)
    }

    /// Date and time pickers in German (16.11.26, 23:00) like every other date in the app, also
    /// on a device set to another language.
    func thaliaDateLocale() -> some View {
        environment(\.locale, Locale(identifier: "de_AT"))
    }
}

// MARK: Contrast (R44)
// WCAG contrast ratios, computed from sRGB relative luminance. `Brand.accent` and the goal colours
// (`GoalPalette.colors`) stay as they are.

extension Color {
    /// Teal behind white text and symbols (asset "ThaliaAccentFill").
    /// Light mode: the icon teal #13707F – white on it 5.75:1 (same colour as `Brand.accent`).
    /// Dark mode: a deeper teal #0C6675 – white on it 6.62:1 (white on the dark `Brand.accent`
    /// #4FB9C7 is only 2.31:1, so that one stays for tints, outlines and text).
    static var accentFill: Color { Color("ThaliaAccentFill") }
}

extension Optional where Wrapped == Mark {
    /// Text and symbols in a mark's colour – buttons, week cells, short symbols (assets "Mark…Text").
    /// Light mode, darker than the system colours (those reach only 2.2–3.6:1 on white):
    ///   Erledigt #1E7D3A – 5.19:1 on white, 4.78:1 on its 10 % tint;
    ///   Teilweise #A85700 – 5.21:1 on white, 4.81:1 on its 10 % tint;
    ///   Nicht erledigt #C62828 – 5.62:1 on white, 4.92:1 on its 10 % tint.
    /// Dark mode: the system colours #30D158, #FF9F0A, #FF453A – 8.4, 8.3 and 5.0:1 on the dark card.
    var textColor: Color {
        switch self {
        case .done?: Color("MarkDoneText")
        case .partial?: Color("MarkPartialText")
        case .missed?: Color("MarkMissedText")
        case .notApplicable?: Color.secondary
        case nil: Color.secondary.opacity(0.6)
        }
    }
}
