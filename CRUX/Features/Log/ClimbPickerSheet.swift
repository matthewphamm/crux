import SwiftUI

/// Pick a problem that's already on the wall to add to the running session.
struct ClimbPickerSheet: View {
    let climbs: [Climb]
    var excluding: Set<UUID> = []
    let onPick: (Climb) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var grade: HexGrade?
    @State private var wallID: UUID?
    @State private var pickTick = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    gradeStrip
                    wallStrip
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { climb in
                            Button {
                                pickTick += 1
                                onPick(climb)
                                dismiss()
                            } label: {
                                row(climb)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Adds it to this session")
                        }
                    }
                    .animation(.smooth, value: filtered.map(\.id))
                    if filtered.isEmpty {
                        ContentUnavailableView(
                            query.isEmpty ? "Nothing else on the wall" : "No matches",
                            systemImage: "hexagon",
                            description: Text(query.isEmpty ? "Add a new climb instead." : "Try a different search.")
                        )
                        .padding(.top, 30)
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 20)
            }
            .nightGymBackground()
            .navigationTitle("Add from the wall")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name, color, tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .cruxFeedback(.selection, trigger: grade)
            .cruxFeedback(.selection, trigger: wallID)
            .cruxFeedback(.impact(weight: .light), trigger: pickTick)
        }
        .presentationDetents([.large])
    }

    private var walls: [Wall] {
        var seen = Set<UUID>()
        return climbs.compactMap(\.wall).filter { seen.insert($0.id).inserted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var filtered: [Climb] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        return climbs
            .filter { !excluding.contains($0.id) }
            .filter { grade == nil || $0.grade == grade }
            .filter { wallID == nil || $0.wall?.id == wallID }
            .filter { climb in
                q.isEmpty
                    || climb.displayName.lowercased().contains(q)
                    || climb.holdColor.name.lowercased().contains(q)
                    || climb.styleTags.contains { $0.rawValue.contains(q) }
            }
            .sorted { ($0.hasSent ? 1 : 0, -$0.gradeValue) < ($1.hasSent ? 1 : 0, -$1.gradeValue) }
    }

    private var gradeStrip: some View {
        HStack(spacing: 6) {
            ForEach(HexGrade.allCases) { option in
                Button {
                    withAnimation(Theme.spring) { grade = grade == option ? nil : option }
                } label: {
                    HexBadge(grade: option, color: .black, size: 38, glowing: grade == option)
                        .opacity(grade == nil || grade == option ? 1 : 0.4)
                        .scaleEffect(grade == option ? 1.08 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(grade == option ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var wallStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(walls) { wall in
                    Button {
                        withAnimation(Theme.spring) { wallID = wallID == wall.id ? nil : wall.id }
                    } label: {
                        TagPill(text: wall.name, isSelected: wallID == wall.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ climb: Climb) -> some View {
        HStack(spacing: 12) {
            HexBadge(grade: climb.grade, color: climb.holdColor, size: 40, glowing: climb.status.isTopped)
            VStack(alignment: .leading, spacing: 2) {
                Text(climb.displayName).font(.headline).foregroundStyle(Theme.ink)
                Text([climb.wall?.name, climb.grade.vRange].compactMap(\.self).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            StatusLabel(status: climb.status)
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
        }
        .glassCard(padding: 12)
        .contentShape(.rect)
    }
}
