import SwiftUI

/// A climb in the live session. Swipe right to send (inferred flash / send / repeat),
/// swipe left to add a try, tap to open the climb.
struct SwipeLogRow: View {
    let climb: Climb
    let session: ClimbSession?
    let onOpen: () -> Void

    @Environment(LogCoordinator.self) private var logger
    @State private var offset: CGFloat = 0
    @State private var axis: Axis?
    @State private var armed = false

    private static let threshold: CGFloat = 90
    private static let limit: CGFloat = 170

    var body: some View {
        ZStack {
            revealBackground
            row
                .offset(x: offset)
        }
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .contentShape(.rect)
        .simultaneousGesture(drag)
        .onTapGesture { if offset == 0 { onOpen() } }
        .cruxFeedback(.selection, trigger: armed)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Swipe right to log a send, left to add a try")
        .accessibilityAction(named: "Add a try") { logger.log(.attempt, on: climb) }
        .accessibilityAction(named: "Log \(predicted.name.lowercased())") { logger.log(.send, on: climb) }
        .accessibilityAction(named: "Open climb", onOpen)
    }

    // MARK: Row

    private var row: some View {
        HStack(spacing: 14) {
            HexBadge(
                grade: climb.grade,
                color: climb.holdColor,
                size: 42,
                glowing: topped,
                bloom: logger.bloom[climb.id] ?? 0
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Text(climb.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if climb.isProjectFlagged || climb.status == .project {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                    }
                }
                if sessionTries.isEmpty {
                    Text("No tries today")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkTertiary)
                } else {
                    TryTrail(attempts: sessionTries, dot: 7)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(topped ? Color(hex: 0x1B2620) : Color(hex: 0x1C1D21))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .strokeBorder(topped ? Theme.send.opacity(0.25) : Theme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var trailing: some View {
        if let send = sessionTries.last(where: \.isSend) {
            Image(systemName: send.sendType == .flash ? "bolt.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(send.sendType == .flash ? Theme.accent : Theme.send)
                .transition(.scale.combined(with: .opacity))
        } else {
            Text("\(sessionTries.count)")
                .font(.number(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(sessionTries.count)))
                .frame(width: 40, height: 40)
                .controlBackground(Circle())
        }
    }

    // MARK: Swipe

    private var revealBackground: some View {
        ZStack {
            if offset > 0 {
                Theme.send
                HStack {
                    Label(predicted.name, systemImage: predicted.symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.onSend)
                        .scaleEffect(armed ? 1.12 : 1)
                        .padding(.leading, 22)
                    Spacer()
                }
            } else if offset < 0 {
                Theme.accent
                HStack {
                    Spacer()
                    Label("Try", systemImage: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .scaleEffect(armed ? 1.12 : 1)
                        .padding(.trailing, 22)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: armed)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if axis == nil {
                    axis = abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
                }
                guard axis == .horizontal else { return }
                offset = max(-Self.limit, min(Self.limit, value.translation.width))
                armed = abs(offset) >= Self.threshold
            }
            .onEnded { _ in
                defer { axis = nil }
                guard axis == .horizontal else { return }
                let final = offset
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    offset = 0
                    armed = false
                }
                if final >= Self.threshold {
                    logger.log(.send, on: climb)
                } else if final <= -Self.threshold {
                    logger.log(.attempt, on: climb)
                }
            }
    }

    // MARK: Data

    private var sessionTries: [Attempt] {
        guard let session else { return [] }
        return climb.chronologicalAttempts.filter { $0.session?.id == session.id }
    }

    private var topped: Bool { sessionTries.contains(where: \.isSend) }

    /// What a right swipe will record.
    private var predicted: SendType {
        SendType.inferred(fromPrior: climb.chronologicalAttempts.map(\.outcome))
    }
}

/// One dot per attempt: grey attempt, green send, amber flash.
struct TryTrail: View {
    let attempts: [Attempt]
    var dot: CGFloat = 7

    var body: some View {
        HStack(spacing: dot * 0.55) {
            ForEach(attempts) { attempt in
                Circle()
                    .fill(color(attempt))
                    .frame(width: dot, height: dot)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityLabel("\(Format.tries(attempts.count))")
    }

    private func color(_ attempt: Attempt) -> Color {
        switch attempt.sendType {
        case .flash: Theme.accent
        case .send, .repeat: Theme.send
        case nil: Theme.inkTertiary
        }
    }
}
