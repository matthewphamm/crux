import SwiftUI

// MARK: - Card

extension View {
    /// The standard card: a faint white fill with a 1pt hairline border.
    /// `tint` recolours fill and border (e.g. green for topped climbs, red for stripped).
    func glassCard(padding: CGFloat = 16, tint: Color? = nil, radius: CGFloat = Theme.Radius.row, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(tint.map { $0.opacity(0.08) } ?? Theme.cardFill))
            .overlay(shape.strokeBorder(tint.map { $0.opacity(0.22) } ?? Theme.cardBorder, lineWidth: 1))
    }

    /// Control style: round toolbar buttons, the gym pill, secondary buttons.
    func controlBackground<S: InsettableShape>(_ shape: S) -> some View {
        background(shape.fill(Theme.controlFill))
            .overlay(shape.strokeBorder(Theme.controlBorder, lineWidth: 1))
    }
}

// MARK: - Buttons

/// Full-width 52pt amber button ("+ Start session", "Resume", "New climb").
struct AccentButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    var fill: Color = Theme.accent
    var ink: Color = Theme.onAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Capsule().fill(fill))
            .shadow(color: fill.opacity(0.35), radius: 12, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Full-width 52pt control-style button ("End", "From the wall", "+ Attempt").
struct ControlButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    var ink: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .controlBackground(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Small pill: "End", "Done", "Reset", "Star".
struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(filled ? Theme.onAccent : tint)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(filled ? tint : tint.opacity(0.14)))
            .overlay(Capsule().strokeBorder(filled ? .clear : tint.opacity(0.3), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// 36pt round control-style icon button (calendar chevrons and similar).
struct RoundIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Theme.accent : Theme.inkTertiary)
            .frame(width: 36, height: 36)
            .controlBackground(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Section header

/// 13 / 600, uppercase, +0.8 tracking, secondary colour.
struct SectionHeader: View {
    let title: String
    var trailing: String?
    var color: Color = Theme.inkSecondary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let caption: String
    var tint: Color = Theme.ink
    var symbol: String?
    /// Colour the number itself (sends in green, hardest in amber).
    var tintsValue = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.9))
                }
                Text(value)
                    .font(.number(size: 24))
                    .foregroundStyle(tintsValue ? tint : Theme.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14, radius: 20)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tag pill

struct TagPill: View {
    let text: String
    var isSelected = false

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isSelected ? Theme.accent : Theme.ink.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(isSelected ? Theme.accent.opacity(0.16) : Theme.controlFill))
            .overlay(Capsule().strokeBorder(isSelected ? Theme.accent.opacity(0.5) : Theme.controlBorder, lineWidth: 1))
    }
}

// MARK: - Status label

struct StatusLabel: View {
    let status: ClimbStatus

    var body: some View {
        Label(status.name, systemImage: status.symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }

    private var color: Color { Self.color(for: status) }

    static func color(for status: ClimbStatus) -> Color {
        switch status {
        case .untried: Theme.inkTertiary
        case .working: Theme.inkSecondary
        case .project: Theme.accent
        case .sent, .flashed: Theme.send
        }
    }
}

// MARK: - Flow layout

/// Wraps children onto new lines, for tag pickers.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if rows[rows.count - 1].width + size.width > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                let y = rows[rows.count - 1].y + rows[rows.count - 1].height + spacing
                rows.append(Row(y: y))
            }
            var row = rows[rows.count - 1]
            row.width += size.width + (row.indices.isEmpty ? 0 : spacing)
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

// MARK: - Toast

struct Toast: Equatable, Identifiable {
    let id = UUID()
    let message: String
    var symbol: String = "checkmark"
    var tint: Color = Theme.ink
    var undo: Bool = true

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

struct ToastView: View {
    let toast: Toast
    let onUndo: () -> Void

    @State private var popped = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(toast.tint)
            Text(toast.message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            if toast.undo {
                Button("Undo", action: onUndo)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Capsule().fill(Color(hex: 0x2C2D32, opacity: 0.94)))
        .background(.ultraThinMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .scaleEffect(popped ? 1 : 1.08)
        .onAppear { withAnimation(.easeOut(duration: 0.25)) { popped = true } }
        .padding(.horizontal, Theme.Spacing.gutter)
    }
}

// MARK: - Formatting

enum Format {
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(Int(interval / 60), 0)
        guard minutes > 0 else { return "<1m" }
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }

    static func clock(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// "90 min", or "30 sec" for the short developer timeouts.
    static func timeout(_ seconds: TimeInterval) -> String {
        seconds < 60 ? "\(Int(seconds)) sec" : "\(Int(seconds / 60)) min"
    }

    /// "1 try", "3 tries".
    static func tries(_ value: Int) -> String {
        value == 1 ? "1 try" : "\(value) tries"
    }

    /// "Today", "Yesterday", or "Tue, Oct 14".
    static func relativeDay(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// "1 send", "3 sends".
    static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    static func decimal(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    static func daysAgo(_ days: Int?) -> String {
        switch days {
        case nil: "Never reset"
        case 0: "Reset today"
        case 1: "Reset yesterday"
        case let d?: "Reset \(d) days ago"
        }
    }
}

// MARK: - Segmented control

/// Track `rgba(255,255,255,.06)` with a sliding `.14` selection; radius 18 (inner 15).
struct CruxSegmented<Value: Hashable & Identifiable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let selected = option == selection
                Button {
                    withAnimation(Theme.spring) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.system(size: 14, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Theme.ink : Theme.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Theme.segmentSelected)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.segmentTrack))
        .cruxFeedback(.selection, trigger: selection)
    }
}
