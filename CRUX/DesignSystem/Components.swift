import SwiftUI

// MARK: - Glass card

extension View {
    /// A Liquid Glass panel with the standard card radius and padding.
    func glassCard(padding: CGFloat = 16, tint: Color? = nil, interactive: Bool = false) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                interactive ? Glass.regular.tint(tint?.opacity(0.18)).interactive() : Glass.regular.tint(tint?.opacity(0.18)),
                in: .rect(cornerRadius: Theme.Radius.card)
            )
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.9))
                }
                Text(value)
                    .font(.number(.title2))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let title: String
    var value: String?
    var isActive: Bool
    var symbol: String?

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.caption.weight(.semibold)) }
            Text(value ?? title)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .opacity(0.6)
        }
        .foregroundStyle(isActive ? Theme.accent : Theme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(isActive ? .regular.tint(Theme.accent.opacity(0.2)).interactive() : .regular.interactive(), in: .capsule)
        .animation(Theme.spring, value: isActive)
    }
}

// MARK: - Tag pill

struct TagPill: View {
    let text: String
    var isSelected = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(isSelected ? Theme.accent : Theme.inkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isSelected ? Theme.accent.opacity(0.16) : Theme.surfaceRaised.opacity(0.7))
            )
            .overlay(Capsule().stroke(isSelected ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1))
    }
}

// MARK: - Status label

struct StatusLabel: View {
    let status: ClimbStatus

    var body: some View {
        Label(status.name, systemImage: status.symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }

    private var color: Color {
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(toast.tint)
            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Spacer(minLength: 8)
            if toast.undo {
                Button("Undo", action: onUndo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Theme.Spacing.gutter)
    }
}

// MARK: - Formatting

enum Format {
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(Int(interval / 60), 0)
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
