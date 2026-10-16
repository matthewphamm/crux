import Observation
import SwiftUI

/// Which tab is showing. Shared so the custom tab bar (drawn per screen) can switch tabs.
@Observable
final class TabRouter {
    var tab: AppTab = .home
}

/// The floating glass capsule: Home · Climbs · [Start] · Walls · Stats.
struct CruxTabBar: View {
    @Environment(TabRouter.self) private var router
    @Environment(SessionManager.self) private var sessions
    @Environment(LogCoordinator.self) private var logger
    @State private var switchTick = 0

    var body: some View {
        HStack(spacing: 2) {
            item(.home, "Home", "hexagon.fill")
            item(.climbs, "Climbs", "list.bullet")
            start
            item(.walls, "Walls", "square.3.layers.3d")
            item(.stats, "Stats", "chart.bar")
        }
        .padding(.horizontal, 6)
        .frame(height: 64)
        .background(Capsule().fill(Color(hex: 0x26272C, opacity: 0.74)))
        .background(.ultraThinMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 16, y: 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .cruxFeedback(.selection, trigger: switchTick)
    }

    private func item(_ tab: AppTab, _ title: String, _ symbol: String) -> some View {
        let selected = router.tab == tab
        return Button {
            guard router.tab != tab else { return }
            switchTick += 1
            withAnimation(.easeInOut(duration: 0.25)) { router.tab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 24)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(selected ? Theme.accent : Theme.tabIdle)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                if selected {
                    Capsule().fill(Color.white.opacity(0.09))
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var start: some View {
        Button {
            logger.openSession()
        } label: {
            if let session = sessions.activeSession {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 7, height: 7)
                        .shadow(color: Theme.accent, radius: 4)
                    TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                        Text(Format.clock(context.date.timeIntervalSince(session.startedAt)))
                            .font(.number(size: 14, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Capsule().fill(Theme.accent.opacity(0.16)))
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1.5))
                .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Theme.accent))
                    .shadow(color: Theme.accent.opacity(0.45), radius: 9, y: 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 64)
        .padding(.horizontal, 4)
        .animation(Theme.spring, value: sessions.activeSession?.id)
        .accessibilityLabel(sessions.activeSession == nil ? "Start session" : "Open session")
    }
}

extension View {
    /// Shows the floating tab bar under a tab's root screen and hides the system one.
    /// Pushed screens don't carry it, so it slides away with the push.
    func cruxTabBar() -> some View {
        self
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { CruxTabBar() }
    }
}
