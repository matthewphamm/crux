import SwiftData
import SwiftUI

struct WallDetailView: View {
    @Bindable var wall: Wall

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var draftName = ""
    @State private var confirmingReset = false
    @State private var confirmingDelete = false
    @State private var resetTick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Format.daysAgo(wall.daysSinceReset()))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if let date = wall.lastResetAt {
                        Text(date.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Button {
                        confirmingReset = true
                    } label: {
                        Label("Mark reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .padding(.top, 10)
                    .disabled(wall.activeClimbs.isEmpty)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
                    SectionHeader(title: "On the wall", trailing: "\(wall.activeClimbs.count)")
                    ForEach(wall.activeClimbs.sorted { $0.gradeValue > $1.gradeValue }) { climb in
                        NavigationLink(value: climb) { ClimbRow(climb: climb) }
                            .buttonStyle(.plain)
                    }
                }
                .animation(Theme.spring, value: wall.activeClimbs.map(\.id))

                if !wall.sortedResets.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
                        SectionHeader(title: "Reset history")
                        VStack(spacing: 0) {
                            ForEach(wall.sortedResets) { reset in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reset.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.ink)
                                        if !reset.note.isEmpty {
                                            Text(reset.note).font(.caption).foregroundStyle(Theme.inkSecondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(reset.strippedCount) stripped")
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkTertiary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .glassCard()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, 24)
        }
        .nightGymBackground()
        .navigationTitle(wall.name)
        .navigationDestination(for: Climb.self) { ClimbDetailView(climb: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        draftName = wall.name
                        renaming = true
                    }
                    Button("Delete wall", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .alert("Rename wall", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Save") {
                let name = draftName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { wall.name = name; try? context.save() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Mark \(wall.name) as reset?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Strip \(wall.activeClimbs.count) climbs", role: .destructive) {
                withAnimation(Theme.spring) { ResetService.reset(wall, in: context) }
                resetTick += 1
            }
        } message: {
            Text("Climbs on this wall move to Stripped. Their logs and beta stay in your history.")
        }
        .confirmationDialog("Delete \(wall.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete wall", role: .destructive) {
                context.delete(wall)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Climbs stay in your history without a wall.")
        }
        .cruxFeedback(.warning, trigger: resetTick)
    }
}
