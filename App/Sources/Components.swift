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
        // Clearing only where there is something to clear (R9).
        if current != nil {
            Divider()
            Button {
                onSet(nil)
            } label: {
                Label("Leeren (nicht erfasst)", systemImage: "circle.dashed")
            }
        }
    }
}

/// A compact cell for the weekly sheet.
struct MarkCell: View {
    let mark: Mark?
    let applies: Bool
    var isToday = false
    var suggestion: Mark?
    /// The marks this item allows that day (no "Entfällt" once a weekly quota needs the day; none on free
    /// days and for automatic items).
    var options: [Mark] = Mark.allCases
    /// R65: the mark has a note – a small dot in the corner.
    var hasNote = false
    /// R66: read before the mark ("Mittwoch, Fahrrad fahren").
    var accessibilityPrefix = ""
    /// R63: tooltip ("Mi, 18. Nov. · Erledigt").
    var help = ""
    /// R9: automatic items – a tap opens the value behind them instead of marking.
    var onOpenValue: (() -> Void)? = nil
    /// R65: "Notiz erfassen…" in the context menu.
    var onAddNote: (() -> Void)? = nil
    /// v8: a mark recorded on a sick or holiday day – kept but not counted, shown dimmed.
    var dimmedMark: Mark? = nil
    /// v8: "Krank" on a sick or holiday day (read out: "zählt nicht").
    var excusedName: String? = nil
    let onSet: (Mark?) -> Void

    @State private var hovering = false

    /// Nothing to mark and nothing to open: dimmed, no tap, no menu (R9).
    private var isInert: Bool { options.isEmpty && onOpenValue == nil }

    /// Automatic item: the tap opens its value.
    private var opensValue: Bool { options.isEmpty && onOpenValue != nil }

    /// Click: the next allowed mark, after the last one empty again.
    private var next: Mark? {
        guard let mark, let index = options.firstIndex(of: mark) else { return mark == nil ? options.first : nil }
        return index + 1 < options.count ? options[index + 1] : nil
    }

    private var borderColor: Color {
        if isToday { return Brand.accent }
        if hovering { return Brand.accent.opacity(0.6) }
        return Color.secondary.opacity(applies ? 0.25 : 0.1)
    }

    private var borderWidth: CGFloat {
        isToday || hovering ? 1.5 : 1
    }

    private var dimming: Double {
        if isInert { return 0.35 }
        return opensValue ? 0.6 : 1
    }

    private var spokenText: String {
        var parts: [String] = []
        if accessibilityPrefix.isEmpty {
            parts.append(mark.accessibilityText)
        } else {
            // R66: "Mittwoch, Fahrrad fahren, nicht erfasst".
            parts.append(accessibilityPrefix)
            parts.append(mark.accessibilityText.lowercased())
        }
        if let excusedName { parts.append("\(excusedName), zählt nicht") }
        if let dimmedMark { parts.append("eingetragen war \(dimmedMark.label)") }
        if !applies { parts.append("nicht geplant") }
        if opensValue { parts.append("automatisch") }
        if hasNote { parts.append("mit Notiz") }
        return parts.joined(separator: ", ")
    }

    private var hintText: String {
        opensValue ? "Öffnet den Wert" : ""
    }

    var body: some View {
        if isInert {
            face
                .opacity(dimming)
                .help(help)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenText)
        } else {
            Button(action: tap) {
                face
            }
            .buttonStyle(.plain)
            .opacity(dimming)
            .onHover { hovering = $0 }
            .help(help)
            .contextMenu { menu }
            .sensoryFeedback(.selection, trigger: mark)
            .accessibilityLabel(spokenText)
            .accessibilityHint(hintText)
        }
    }

    private func tap() {
        if opensValue, let onOpenValue {
            onOpenValue()
        } else {
            onSet(next)
        }
    }

    private var face: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(applies ? Color.cardBackground : Color.clear)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(borderColor, style: StrokeStyle(lineWidth: borderWidth, dash: applies ? [] : [2, 3]))
                if let dimmedMark {
                    // v8: recorded before the day became sick / holiday – it doesn't count.
                    Text(dimmedMark.symbol)
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                } else if let mark {
                    Text(mark.symbol)
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(Optional(mark).textColor)
                } else if let suggestion {
                    Text(suggestion.symbol)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Optional(suggestion).color.opacity(0.45))
                }
            }
            if hasNote {
                Circle()
                    .fill(Brand.accent)
                    .frame(width: 4, height: 4)
                    .padding(3)
                    .accessibilityHidden(true)
            }
        }
        .frame(minWidth: 30, minHeight: 30)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var menu: some View {
        if !options.isEmpty {
            MarkMenu(current: mark, options: options, onSet: onSet)
        }
        if let onOpenValue {
            Button("Wert eintragen…", systemImage: "square.and.pencil", action: onOpenValue)
        }
        if let onAddNote {
            Divider()
            Button(noteTitle, systemImage: "note.text", action: onAddNote)
        }
    }

    private var noteTitle: String {
        hasNote ? "Notiz bearbeiten…" : "Notiz erfassen…"
    }
}

extension MarkCell {
    /// R9: where a tap on an automatic item leads – the value behind it (work → power-hours with the
    /// area, spending → the spending sheet, else the measurement). nil for items you mark yourself.
    static func valueSheet(for item: PlanItem, context: WeekContext, day: DayKey) -> AppSheet? {
        guard context.isDerived(item) else { return nil }
        guard let measure = context.measure(code: item.measureCode) else {
            return .measure(code: item.measureCode, day: day)
        }
        return valueSheet(for: measure, context: context, day: day)
    }

    /// The sheet that records a measurement's value on a day (R9, R85).
    static func valueSheet(for measure: MeasureDefinition, context: WeekContext, day: DayKey) -> AppSheet {
        if let record = measure.record, case .work(let category) = record.source {
            let area: String = category.isEmpty ? measure.categoryKey : category
            return .work(WorkDraft(day: day, categoryKey: area))
        }
        if context.isExpense(measure) { return .expenses(day) }
        return .measure(code: measure.code, day: day)
    }
}

/// Score 0–10 as a ring; the inner thin ring shows how much of the day is recorded.
struct ScoreRing: View {
    let score: Double?
    var coverage: Double?
    var size: CGFloat = 84
    var lineWidth: CGFloat = 9
    var caption: String?
    /// R68: the goal's colour where the ring belongs to a goal.
    var tint: Color = Brand.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat((score ?? 0) / 10))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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

/// The annual goals as equal-width bars: they count equally in the week.
struct GoalBars: View {
    let scores: [Double?]
    var height: CGFloat = 38
    /// R68: the goals' keys, parallel to `scores` – bars in the goal colours. Empty: accent colour.
    var keys: [String] = []

    private func color(at index: Int) -> Color {
        keys.indices.contains(index) ? GoalPalette.color(goal: keys[index]) : Brand.accent
    }

    private func label(at index: Int) -> String {
        keys.indices.contains(index) ? keys[index] : "\(index + 1)"
    }

    private func barHeight(_ score: Double?) -> CGFloat {
        let value: Double = score ?? 0
        return height * CGFloat(min(1, max(0, value / 10)))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                VStack(spacing: 2) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(score == nil ? Color.clear : color(at: index))
                            .frame(height: barHeight(score))
                    }
                    .frame(height: height)
                    Text(label(at: index))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jahresziele, gleich gewichtet")
    }
}

/// "1.1" in a small capsule.
struct KeyBadge: View {
    let key: String
    /// R67: the capsule grows with the text; identical at the standard size.
    @ScaledMetric(relativeTo: .caption2) private var horizontalPadding: CGFloat = 6
    @ScaledMetric(relativeTo: .caption2) private var verticalPadding: CGFloat = 2

    var body: some View {
        Text(key)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(GoalPalette.color(category: key).opacity(0.16), in: .capsule)
            .foregroundStyle(GoalPalette.color(category: key))
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

/// v8: the day type as a quick choice – Krank and Urlaub on top (they don't count in the week's
/// score), then the other presets and "Eigener Typ…" (the day editor). Used in Today's title
/// menu, the week's day heads and closing the day. `app` is passed in so the menu works in
/// context menus, too.
struct DayTypeMenu: View {
    let app: AppModel
    let day: DayKey
    let current: String
    var title: String = "Tagestyp"
    /// "Tagestyp: Krank" in the label; off for "Typ ändern".
    var showsCurrent = true

    private var labelText: String {
        showsCurrent && !current.isEmpty ? "\(title): \(current)" : title
    }

    private var otherPresets: [String] {
        DayTypes.presets.filter { !DayTypes.excusedPresets.contains($0) }
    }

    var body: some View {
        Menu {
            Section {
                ForEach(DayTypes.excusedPresets, id: \.self) { type in
                    choice(type)
                }
            } header: {
                Text("Zählt nicht in die Wochenwertung")
            }
            Section {
                ForEach(otherPresets, id: \.self) { type in
                    choice(type)
                }
            }
            // No "clear" entry on purpose: an empty type can come back from an offline copy (the
            // newest non-empty type wins when duplicates merge) – "Arbeitstag" undoes "Krank".
            Section {
                Button("Eigener Typ…", systemImage: "pencil") { app.sheet = .dayInfo(day) }
            }
        } label: {
            Label(labelText, systemImage: DayTypes.symbol(for: current))
        }
    }

    @ViewBuilder
    private func choice(_ type: String) -> some View {
        if type == current {
            Button(type, systemImage: "checkmark") { }
                .disabled(true)
        } else {
            Button(type, systemImage: DayTypes.symbol(for: type)) { app.setDayType(type, day: day) }
        }
    }
}

/// v8: on a sick or holiday day – "Krank – dieser Tag zählt nicht in die Wochenwertung" with
/// "Typ ändern" (Today, closing the day).
struct ExcusedDayCard: View {
    let app: AppModel
    let day: DayKey
    let type: String

    private var name: String { WeekContext.excusedName(for: type) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: DayTypes.symbol(for: type))
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(name) – dieser Tag zählt nicht in die Wochenwertung")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Nichts ist fällig. Werte lassen sich trotzdem eintragen. Bei „n× pro Woche“ zählt, was deshalb fehlt, halb.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                DayTypeMenu(app: app, day: day, current: type, title: "Typ ändern", showsCurrent: false)
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 12)
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

// MARK: v7 building blocks

/// R64: how an item counts ("Nebensache", "automatisch", "3× pro Woche") – takes
/// `context.kindLabel(item)` directly; nil or empty shows nothing.
struct KindBadge: View {
    let text: String?

    init(text: String?) {
        self.text = text
    }

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .foregroundStyle(.secondary)
                .background(Color.secondary.opacity(0.12), in: .capsule)
        }
    }
}

/// R90: the plan's note for the day ("Besonderheit: …"); nothing for an empty note.
struct DayNoteLabel: View {
    let note: String

    init(note: String) {
        self.note = note
    }

    private var trimmed: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if !trimmed.isEmpty {
            Label {
                Text("Besonderheit: \(trimmed)")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "pin.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
    }
}

/// R32: earlier answers as one-tap chips – those containing what was typed (any case), without the
/// one already chosen, at most `limit`.
struct SuggestionChips: View {
    let suggestions: [String]
    let typed: String
    let selected: String
    var limit: Int = 6
    let onPick: (String) -> Void

    init(suggestions: [String], typed: String, selected: String, limit: Int = 6, onPick: @escaping (String) -> Void) {
        self.suggestions = suggestions
        self.typed = typed
        self.selected = selected
        self.limit = limit
        self.onPick = onPick
    }

    /// The chips shown, in the order given (most used first).
    static func filtered(_ suggestions: [String], typed: String, selected: String, limit: Int) -> [String] {
        let query: String = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen: String = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen: Set<String> = []
        var result: [String] = []
        for suggestion in suggestions {
            guard result.count < limit else { break }
            let text: String = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if !query.isEmpty && !text.localizedCaseInsensitiveContains(query) { continue }
            if !chosen.isEmpty && text.localizedCaseInsensitiveCompare(chosen) == .orderedSame { continue }
            guard seen.insert(text.lowercased()).inserted else { continue }
            result.append(text)
        }
        return result
    }

    var body: some View {
        let shown: [String] = Self.filtered(suggestions, typed: typed, selected: selected, limit: limit)
        if !shown.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(shown, id: \.self) { suggestion in
                        ChipButton(title: suggestion, isSelected: false) { onPick(suggestion) }
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Vorschläge")
        }
    }
}

/// R41: "Tag: Heute · Gestern · Datum" at the top of every capture sheet, with an orange hint as
/// soon as the entry counts for another day.
struct CaptureDayRow: View {
    @Binding var day: DayKey
    let today: DayKey

    init(day: Binding<DayKey>, today: DayKey) {
        self._day = day
        self.today = today
    }

    private var yesterday: DayKey { today.adding(days: -1) }

    private var date: Binding<Date> {
        Binding(get: { day.startDate() }, set: { day = DayKey(date: $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WrapLayout(spacing: 6) {
                Text("Tag:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipButton(title: "Heute", isSelected: day == today) { day = today }
                ChipButton(title: "Gestern", isSelected: day == yesterday) { day = yesterday }
                DatePicker("Datum", selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .thaliaDateLocale()
                    .datePickerStyle(.compact)
            }
            if day != today {
                Label("Zählt für \(day.shortLabel) – nicht für heute", systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .animation(.snappy, value: day)
    }
}

/// R41: "Power-Hours" for today, "Power-Hours · So, 15. Nov." for another day.
func captureTitle(_ base: String, day: DayKey, today: DayKey) -> String {
    day == today ? base : "\(base) · \(day.shortLabel)"
}

/// R33/R78: chips that wrap into further lines instead of being cut off.
struct WrapLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth: CGFloat = proposal.width ?? .infinity
        let (rows, _) = arrange(maxWidth: maxWidth, subviews: subviews)
        let width: CGFloat = rows.map(\.width).max() ?? 0
        let gaps: CGFloat = spacing * CGFloat(max(0, rows.count - 1))
        let height: CGFloat = rows.reduce(CGFloat(0)) { $0 + $1.height } + gaps
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (rows, sizes) = arrange(maxWidth: bounds.width, subviews: subviews)
        var y: CGFloat = bounds.minY
        for row in rows {
            var x: CGFloat = bounds.minX
            for index in row.indices {
                let size: CGSize = sizes[index]
                let top: CGFloat = y + (row.height - size.height) / 2
                subviews[index].place(at: CGPoint(x: x, y: top), anchor: .topLeading,
                                      proposal: ProposedViewSize(width: size.width, height: size.height))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    /// Fills each line as far as it goes; a view wider than a line gets a line of its own.
    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> ([Row], [CGSize]) {
        var sizes: [CGSize] = []
        for subview in subviews {
            var size: CGSize = subview.sizeThatFits(.unspecified)
            if maxWidth.isFinite && size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            sizes.append(size)
        }
        var rows: [Row] = []
        var current = Row()
        for (index, size) in sizes.enumerated() {
            let needed: CGFloat = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return (rows, sizes)
    }
}

/// v11 P1.7, P1.16: how a weekly target reads on screen and in the PDF – one place for Week, the Mac panel,
/// "Heute im Blick", the weekly-goals sheet and the week's PDF.
extension WeeklyTarget {
    /// Where the target stands, by the report's rule (`PaceStatus.of`): a limit "im Rahmen" / "überschritten"; met
    /// "erreicht" (a range or "=" compares both ways); else the pace – "im Plan", "hinter dem Plan", "noch offen"
    /// (last planned day), "nicht erreicht" (the week is over or closed).
    var shownStatus: PaceStatus {
        PaceStatus.of(target: target, value: value, pace: pace)
    }

    /// The unit the amounts are rounded and written with: "PH" for work, else the measure's own (times, €).
    var amountUnit: String { unit == "PH" ? "PH" : measure.unit }

    /// " PH", " Stk.", " €" after the amounts; nothing for times.
    var amountSuffix: String {
        if Units.isTime(amountUnit) { return "" }
        if Units.normalized(amountUnit) == "€" { return " €" }
        return unit.isEmpty ? "" : " " + unit
    }

    /// "6 von 8 PH", "150 von 86 Stk.", "32,50 von ≤ 50 €" – rounded for the screen, the target in the direction of
    /// its comparison (`Format.amount`); "erreicht" still comes from the exact values.
    func amountsText(joiner: String = " von ") -> String {
        let value: String = Format.amount(self.value, unit: amountUnit)
        let goal: String = Format.amount(target: target, unit: amountUnit)
        return value + joiner + goal + amountSuffix
    }
}

/// R16/R47: one weekly target – a bar in the goal's colour with the even-pace marker ("Soll bis
/// heute") and "6 von 8 PH – im Plan". v11 P1.16: the status word and its colour from `PaceStatus` and
/// `StatusTint` alone (a limit kept in the accent, exceeded in red).
struct WeeklyTargetRow: View {
    let target: WeeklyTarget
    var onOpen: (() -> Void)?

    init(target: WeeklyTarget, onOpen: (() -> Void)? = nil) {
        self.target = target
        self.onOpen = onOpen
    }

    private var tint: Color { GoalPalette.color(category: target.measure.categoryKey) }

    private var title: String { target.item?.title ?? target.measure.title }

    private var isLimit: Bool { target.target.isLimit }

    /// "6 von 8 PH – im Plan", "12 von 12,8 PH – noch offen" – the short word next to "x von y" (KR2-12).
    private var status: String { "\(target.amountsText()) – \(target.shownStatus.label)" }

    private var statusColor: Color { StatusTint(target.shownStatus).color }

    private var barColor: Color {
        if isLimit || target.pace.isReached || target.shownStatus == .reached { return statusColor }
        return tint
    }

    /// Where an even pace stands today, 0…1 of the bar; nil once reached.
    private var marker: Double? {
        let pace: Pace = target.pace
        guard pace.target > 0, pace.expected > 0, !pace.isReached, target.shownStatus != .reached else { return nil }
        return min(1, pace.expected / pace.target)
    }

    var body: some View {
        if let onOpen {
            Button(action: onOpen) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öffnet die Erfassung")
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 6)
                Text(status)
                    .font(.caption)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(statusColor)
                if onOpen != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            bar
            if let hint = target.scaledHint {
                // v8: the target counts only for the days that aren't sick or holiday days.
                Label("Ziel \(hint)", systemImage: "calendar.badge.minus")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }

    private var spokenText: String {
        guard let hint = target.scaledHint else { return "\(title): \(status)" }
        return "\(title): \(status), Ziel \(hint)"
    }

    private var bar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(barColor)
                    .frame(width: max(6, geometry.size.width * target.pace.fraction))
                if let marker {
                    Rectangle()
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: 2, height: 14)
                        .offset(x: geometry.size.width * marker - 1)
                }
            }
        }
        .frame(height: 8)
        .animation(.snappy, value: target.value)
    }
}

/// R16: the one list of weekly targets (the content of a section) – Week, the Mac panel, "Heute im
/// Blick" and the weekly-goals sheet all show this.
struct WeeklyTargetsList: View {
    let context: WeekContext
    var limit: Int?
    var onOpen: ((MeasureDefinition) -> Void)?

    init(context: WeekContext, limit: Int? = nil, onOpen: ((MeasureDefinition) -> Void)? = nil) {
        self.context = context
        self.limit = limit
        self.onOpen = onOpen
    }

    private func shown(_ all: [WeeklyTarget]) -> [WeeklyTarget] {
        guard let limit else { return all }
        return Array(all.prefix(max(0, limit)))
    }

    private func opener(for target: WeeklyTarget) -> (() -> Void)? {
        guard let onOpen else { return nil }
        let measure: MeasureDefinition = target.measure
        return { onOpen(measure) }
    }

    var body: some View {
        let targets: [WeeklyTarget] = shown(context.weeklyTargets)
        if targets.isEmpty {
            Text("Keine Wochenziele in dieser Woche")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(targets) { target in
                WeeklyTargetRow(target: target, onOpen: opener(for: target))
            }
        }
    }
}
