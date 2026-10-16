import SwiftData
import SwiftUI

struct ClimbDetailView: View {
    @Bindable var climb: Climb

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LogCoordinator.self) private var logger
    @Environment(SessionManager.self) private var sessions
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var expandedSession: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                stats
                if climb.isActive {
                    LogButtons(climb: climb)
                } else {
                    strippedNotice
                }
                history
                BetaSection(climb: climb)
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, 32)
        }
        .nightGymBackground(tint: climb.holdColor.glow)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
            if climb.isActive {
                ToolbarItem(placement: .topBarTrailing) { starToggle }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        .logToast()
        .sheet(isPresented: $editing) { ClimbEditorSheet(mode: .edit(climb)) }
        .alert("Delete this climb?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete climb and its history", role: .destructive) { delete() }
        } message: {
            Text("All \(climb.tryCount) logs and any beta media will be removed. To keep history, strip it instead.")
        }
        .cruxFeedback(.selection, trigger: climb.isProjectFlagged)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            HexBadge(
                grade: climb.grade,
                color: climb.holdColor,
                size: 116,
                glowing: true,
                bloom: logger.bloom[climb.id] ?? 0,
                dim: !climb.isActive
            )
            .padding(.bottom, 8)
            Text(climb.displayName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var subtitle: String {
        let wall = climb.wall?.name
        let tags = climb.styleTags.sorted { $0.rawValue < $1.rawValue }.map(\.name)
            .filter { $0.caseInsensitiveCompare(wall ?? "") != .orderedSame }
        return ([climb.grade.vRange, wall] + tags).compactMap(\.self).joined(separator: " · ")
    }

    private var starToggle: some View {
        Button {
            withAnimation(Theme.spring) { climb.isProjectFlagged.toggle() }
            try? context.save()
        } label: {
            Label(climb.isProjectFlagged ? "Starred" : "Star", systemImage: climb.isProjectFlagged ? "star.fill" : "star")
                .labelStyle(.titleAndIcon)
                .symbolEffect(.bounce, value: climb.isProjectFlagged)
        }
        .buttonStyle(PillButtonStyle(filled: climb.isProjectFlagged))
        .accessibilityLabel(climb.isProjectFlagged ? "Unstar project" : "Star as project")
    }

    // MARK: Stats

    private var stats: some View {
        let sessionsCount = Set((climb.attempts ?? []).compactMap { $0.session?.id }).count
        return HStack(spacing: 0) {
            stat(Text("\(climb.tryCount)"), label: climb.tryCount == 1 ? "try" : "tries")
            divider
            stat(Text("\(sessionsCount)"), label: sessionsCount == 1 ? "session" : "sessions")
            divider
            VStack(spacing: 4) {
                if climb.isActive {
                    Label(climb.status.name, systemImage: climb.status.symbol)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(StatusLabel.color(for: climb.status))
                } else {
                    Label("Stripped", systemImage: "archivebox.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.danger)
                }
                Text("status")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 36)
    }

    private func stat(_ value: Text, label: String) -> some View {
        VStack(spacing: 4) {
            value
                .font(.number(size: 22))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var strippedNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.title3)
                .foregroundStyle(Theme.danger)
            VStack(alignment: .leading, spacing: 3) {
                Text("Stripped \(climb.strippedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.danger)
                Text("This problem is no longer on the wall. Its logs and beta are kept. If it's back up, use ⋯ → Restore to wall.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassCard(padding: 16, tint: Theme.danger)
    }

    // MARK: History

    private var history: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "History")
            if bySession.isEmpty {
                Text("No tries yet.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkTertiary)
                    .glassCard(padding: 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bySession.enumerated()), id: \.offset) { index, group in
                        if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        historyRow(group)
                    }
                }
                .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.cardFill))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
            }
        }
    }

    private func historyRow(_ group: (session: ClimbSession?, attempts: [Attempt])) -> some View {
        let id = group.session?.id
        let expanded = id != nil && expandedSession == id
        return VStack(spacing: 0) {
            Button {
                withAnimation(Theme.spring) { expandedSession = expanded ? nil : id }
            } label: {
                HStack {
                    Text(label(for: group.session, fallback: group.attempts.first?.timestamp))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    TryTrail(attempts: group.attempts, dot: 8)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows each try")

            if expanded {
                VStack(spacing: 0) {
                    ForEach(group.attempts.reversed()) { attempt in
                        AttemptRow(attempt: attempt)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }

    private func label(for session: ClimbSession?, fallback: Date?) -> String {
        if let session, session.id == sessions.activeSession?.id { return "This session" }
        guard let date = session?.startedAt ?? fallback else { return "—" }
        return Format.relativeDay(date)
    }

    /// One row per session, newest first, each with that session's tries in order.
    private var bySession: [(session: ClimbSession?, attempts: [Attempt])] {
        let groups = Dictionary(grouping: climb.chronologicalAttempts) { $0.session?.id }
        return groups.values
            .map { attempts in (attempts.first?.session, attempts) }
            .sorted { ($0.1.first?.timestamp ?? .distantPast) > ($1.1.first?.timestamp ?? .distantPast) }
    }

    // MARK: More

    private var moreMenu: some View {
        Menu {
            Button("Edit", systemImage: "pencil") { editing = true }
            Divider()
            if climb.isActive {
                Button("Strip from wall", systemImage: "archivebox") {
                    withAnimation(Theme.spring) { climb.strippedAt = .now }
                    try? context.save()
                }
            } else {
                Button("Restore to wall", systemImage: "arrow.uturn.backward") {
                    withAnimation(Theme.spring) { climb.strippedAt = nil }
                    try? context.save()
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    private func delete() {
        for media in climb.media ?? [] { MediaStore.delete(media.fileName) }
        context.delete(climb)
        try? context.save()
        sessions.refresh()
        dismiss()
    }
}

/// One log in a climb's history. Sends can have their type corrected; any log can be deleted.
struct AttemptRow: View {
    let attempt: Attempt
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(attempt.isSend ? Theme.send : Theme.inkTertiary)
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(attempt.isSend ? Theme.ink : Theme.inkSecondary)
            Spacer()
            Text(attempt.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.number(.caption, weight: .regular))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
        .contextMenu {
            if attempt.isSend {
                Section("Send type") {
                    ForEach(SendType.allCases) { type in
                        Button(type.name, systemImage: type.symbol) {
                            attempt.sendType = type
                            try? context.save()
                        }
                    }
                }
            }
            Button("Delete log", systemImage: "trash", role: .destructive) {
                withAnimation(Theme.spring) {
                    context.delete(attempt)
                    try? context.save()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        attempt.sendType?.symbol ?? "circle"
    }

    private var label: String {
        attempt.sendType?.name ?? "Attempt"
    }
}
