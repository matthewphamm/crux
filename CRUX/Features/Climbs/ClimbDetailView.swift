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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                hero
                if !climb.isActive {
                    strippedNotice
                } else if sessions.activeSession != nil {
                    LogButtons(climb: climb)
                } else {
                    startPrompt
                }
                stats
                BetaSection(climb: climb)
                history
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, 24)
        }
        .nightGymBackground()
        .navigationTitle(climb.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if climb.isActive {
            ToolbarItem(placement: .topBarTrailing) {
                Button(climb.isProjectFlagged ? "Unstar project" : "Star as project",
                       systemImage: climb.isProjectFlagged ? "star.fill" : "star") {
                    withAnimation(Theme.spring) { climb.isProjectFlagged.toggle() }
                    try? context.save()
                }
                .symbolEffect(.bounce, value: climb.isProjectFlagged)
            }
            }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .logToast()
        .sheet(isPresented: $editing) { ClimbEditorSheet(mode: .edit(climb)) }
        .alert("Delete this climb?", isPresented: $confirmingDelete) {
            Button("Delete climb and its history", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(climb.tryCount) logs and any beta media will be removed. To keep history, strip it instead.")
        }
        .cruxFeedback(.selection, trigger: climb.isProjectFlagged)
    }

    // MARK: Sections

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            HexBadge(
                grade: climb.grade,
                color: climb.holdColor,
                size: 84,
                glowing: climb.isActive && climb.status.isTopped,
                bloom: logger.bloom[climb.id] ?? 0
            )
            .saturation(climb.isActive ? 1 : 0)
            .opacity(climb.isActive ? 1 : 0.6)
            VStack(alignment: .leading, spacing: 6) {
                Text(climb.grade.fullLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text([climb.holdColor.name, climb.wall?.name].compactMap(\.self).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                StatusLabel(status: climb.status)
                if !climb.styleTags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(climb.styleTags.sorted { $0.rawValue < $1.rawValue }) { TagPill(text: $0.name) }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .animation(Theme.spring, value: climb.status)
    }

    /// Logging lives in sessions; outside one, offer to start it right here.
    private var startPrompt: some View {
        Button {
            logger.openSession()
            sessions.queue(climb)
        } label: {
            Label("Start a session with this climb", systemImage: "plus")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    private var strippedNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.title3)
                .foregroundStyle(Theme.stripped)
            VStack(alignment: .leading, spacing: 3) {
                Text("Stripped \(climb.strippedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                    .font(.headline)
                    .foregroundStyle(Theme.stripped)
                Text("This problem is no longer on the wall. Its logs and beta are kept. If it's back up, use ⋯ → Restore to wall.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassCard(padding: 16, tint: Theme.stripped.opacity(0.6))
    }

    private var stats: some View {
        let sessionsCount = Set((climb.attempts ?? []).compactMap { $0.session?.id }).count
        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(value: "\(climb.tryCount)", caption: "total tries")
                StatTile(value: "\(sessionsCount)", caption: sessionsCount == 1 ? "session" : "sessions")
            }
            GridRow {
                StatTile(value: climb.triesToFirstSend.map { "\($0)" } ?? "—", caption: "tries to send")
                StatTile(
                    value: climb.firstSend?.timestamp.formatted(.dateTime.month(.abbreviated).day()) ?? "—",
                    caption: climb.firstSend?.sendType == .flash ? "flashed" : "first send"
                )
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "History", trailing: climb.tryCount > 0 ? "\(climb.tryCount) logs" : nil)
            if climb.tryCount == 0 {
                Text("No logs yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkTertiary)
                    .glassCard(padding: 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(grouped.enumerated()), id: \.offset) { index, group in
                        if index > 0 { Divider().overlay(Theme.hairline).padding(.vertical, 6) }
                        Text(group.day.formatted(date: .complete, time: .omitted))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)
                        ForEach(group.attempts) { attempt in
                            AttemptRow(attempt: attempt)
                        }
                    }
                }
                .glassCard()
            }
        }
    }

    private var grouped: [(day: Date, attempts: [Attempt])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: climb.chronologicalAttempts.reversed()) { calendar.startOfDay(for: $0.timestamp) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

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
