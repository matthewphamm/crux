import SwiftUI

/// A glass card holding a stack of settings rows separated by inset hairlines.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 1)
                            .padding(.leading, 64)
                    }
                    row
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }
}

/// Icon tile, title, optional subtitle and a trailing accessory.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    var tint: Color = Theme.accent
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, tint: Color = Theme.accent, title: String, subtitle: String? = nil) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Small − value + control that matches the glass look better than a system Stepper.
struct GlassStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let label: (Int) -> String

    var body: some View {
        HStack(spacing: 6) {
            button("minus", enabled: value - step >= range.lowerBound) { value -= step }
            Text(label(value))
                .font(.number(.subheadline))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(value)))
                .frame(minWidth: 54)
                .lineLimit(1)
            button("plus", enabled: value + step <= range.upperBound) { value += step }
        }
        .cruxFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if value + step <= range.upperBound { value += step }
            case .decrement: if value - step >= range.lowerBound { value -= step }
            @unknown default: break
            }
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.spring, action)
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(enabled ? Theme.accent : Theme.inkTertiary)
                .frame(width: 32, height: 32)
                .controlBackground(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

extension View {
    /// Section title above a settings card.
    func settingsSection(_ title: String, footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
                .padding(.horizontal, 4)
            self
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
