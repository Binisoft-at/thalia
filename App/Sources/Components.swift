import SwiftUI
import BinisoftKit
import ThaliaCore

// Small building blocks shared by the screens. Content sits on plain cards; glass is left to
// floating controls (BinisoftKit theme rules).

extension Optional where Wrapped == Mark {
    var symbolName: String {
        switch self {
        case .done?: "checkmark.circle.fill"
        case .partial?: "circle.lefthalf.filled"
        case .missed?: "xmark.circle.fill"
        case .notApplicable?: "minus.circle"
        case nil: "circle.dashed"
        }
    }

    var color: Color {
        switch self {
        case .done?: .green
        case .partial?: .orange
        case .missed?: .red
        case .notApplicable?: .secondary
        case nil: Color.secondary.opacity(0.6)
        }
    }

    var accessibilityText: String {
        self?.label ?? "Nicht erfasst"
    }
}

/// All marks as menu entries (context menus, the item sheet).
struct MarkMenu: View {
    let current: Mark?
    var options: [Mark] = Mark.allCases
    let onSet: (Mark?) -> Void

    var body: some View {
        ForEach(options, id: \.self) { mark in
            Button {
                onSet(mark)
            } label: {
                Label("\(mark.symbol)  \(mark.label)", systemImage: Optional(mark).symbolName)
            }
            .disabled(current == mark)
        }
        Divider()
        Button {
            onSet(nil)
        } label: {
            Label("Leeren (nicht erfasst)", systemImage: "circle.dashed")
        }
        .disabled(current == nil)
    }
}

/// A compact cell for the weekly sheet.
struct MarkCell: View {
    let mark: Mark?
    let applies: Bool
    var isToday = false
    var suggestion: Mark?
    /// The marks this item allows that day (no N/A once a weekly quota needs the day).
    var options: [Mark] = Mark.allCases
    let onSet: (Mark?) -> Void

    /// Click: the next allowed mark, after the last one empty again.
    private var next: Mark? {
        guard let mark, let index = options.firstIndex(of: mark) else { return mark == nil ? options.first : nil }
        return index + 1 < options.count ? options[index + 1] : nil
    }

    var body: some View {
        Button {
            onSet(next)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(applies ? Color.cardBackground : Color.clear)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isToday ? Brand.accent : Color.secondary.opacity(applies ? 0.25 : 0.1),
                                  style: StrokeStyle(lineWidth: isToday ? 1.5 : 1, dash: applies ? [] : [2, 3]))
                if let mark {
                    Text(mark.symbol)
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(Optional(mark).color)
                } else if let suggestion {
                    Text(suggestion.symbol)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Optional(suggestion).color.opacity(0.45))
                }
            }
            .frame(minWidth: 30, minHeight: 30)
        }
        .buttonStyle(.plain)
        .contextMenu { MarkMenu(current: mark, options: options, onSet: onSet) }
        .sensoryFeedback(.selection, trigger: mark)
        .accessibilityLabel(mark.accessibilityText + (applies ? "" : ", nicht geplant"))
    }
}

/// Score 0–10 as a ring; the inner thin ring shows how much of the day is recorded.
struct ScoreRing: View {
    let score: Double?
    var coverage: Double?
    var size: CGFloat = 84
    var lineWidth: CGFloat = 9
    var caption: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat((score ?? 0) / 10))
                .stroke(Brand.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let coverage {
                Circle()
                    .trim(from: 0, to: CGFloat(coverage))
                    .stroke(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth + 3)
            }
            VStack(spacing: 0) {
                Text(Format.score(score, outOf: false))
                    .font(.system(size: size * 0.27, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, lineWidth)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let caption {
                    Text(caption)
                        .font(.system(size: max(9, size * 0.11)))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score.map { "Wertung \(Format.score($0)) von 10" } ?? "Noch keine Wertung")
    }
}

/// The ten annual goals as equal-width bars: each is 10 % of the week.
struct GoalBars: View {
    let scores: [Double?]
    var height: CGFloat = 38

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                VStack(spacing: 2) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(score == nil ? Color.clear : Brand.accent)
                            .frame(height: height * CGFloat((score ?? 0) / 10))
                    }
                    .frame(height: height)
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zehn Jahresziele, je 10 Prozent der Woche")
    }
}

/// "1.1" in a small capsule.
struct KeyBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Brand.accent.opacity(0.14), in: .capsule)
            .foregroundStyle(Brand.accent)
    }
}

/// "Arbeitstag" chip with its symbol.
struct DayTypeChip: View {
    let type: String
    /// Only the symbol (narrow columns).
    var compact = false

    var body: some View {
        Label(type.isEmpty ? "Tagestyp" : type, systemImage: DayTypes.symbol(for: type))
            .labelStyle(DayTypeLabelStyle(compact: compact))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12), in: .capsule)
    }
}

/// A plain section heading with an optional trailing value.
struct SectionHeading: View {
    let title: String
    var symbol: String?
    var trailing: String?

    var body: some View {
        HStack {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .font(.headline)
    }
}

private struct DayTypeLabelStyle: LabelStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            if !compact { configuration.title }
        }
    }
}
