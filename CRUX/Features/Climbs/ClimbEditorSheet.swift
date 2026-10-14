import PhotosUI
import SwiftData
import SwiftUI

/// Add or edit a climb: grade, hold color, wall, then the optional details.
struct ClimbEditorSheet: View {
    enum Mode {
        case create
        case edit(Climb)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var app
    @Environment(LogCoordinator.self) private var logger
    @AppStorage("editor.lastWallID") private var lastWallID = ""

    @State private var grade: HexGrade = .three
    @State private var color: HoldColor = .blue
    @State private var wallID: UUID?
    @State private var name = ""
    @State private var notes = ""
    @State private var tags: Set<StyleTag> = []
    @State private var onTickList = false
    @State private var isProject = false
    @State private var mediaItems: [PhotosPickerItem] = []
    @State private var newWallName = ""
    @State private var showingNewWall = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    hero
                    gradePicker
                    colorPicker
                    wallPicker
                    tagPicker
                    details
                    if isCreating { betaPicker }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .nightGymBackground()
            .navigationTitle(isCreating ? "New climb" : "Edit climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                if !isCreating {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark") { save(log: nil) }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isCreating { createActions }
            }
            .alert("New wall", isPresented: $showingNewWall) {
                TextField("Name", text: $newWallName)
                Button("Add") { addWall() }
                Button("Cancel", role: .cancel) { newWallName = "" }
            }
            .cruxFeedback(.selection, trigger: grade)
            .cruxFeedback(.selection, trigger: color)
            .onAppear(perform: load)
        }
    }

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private var walls: [Wall] { app.currentGym?.sortedWalls ?? [] }

    // MARK: Sections

    private var hero: some View {
        HStack(spacing: 16) {
            HexBadge(grade: grade, color: color, size: 64, glowing: true)
                .animation(Theme.spring, value: grade)
                .animation(Theme.spring, value: color)
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "\(color.name) \(grade.label)" : name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.interpolate)
                Text("≈ \(grade.vRange)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .contentTransition(.numericText())
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var gradePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Grade", trailing: grade.vRange)
            HStack(spacing: 4) {
                ForEach(HexGrade.allCases) { option in
                    Button {
                        withAnimation(Theme.spring) { grade = option }
                    } label: {
                        HexBadge(grade: option, color: option == grade ? color : .black, size: 42, glowing: option == grade)
                            .scaleEffect(option == grade ? 1.1 : 0.94)
                            .opacity(option == grade ? 1 : 0.6)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.fullLabel)
                    .accessibilityAddTraits(option == grade ? .isSelected : [])
                }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Hold color", trailing: color.name)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(HoldColor.allCases) { option in
                    Button {
                        withAnimation(Theme.spring) { color = option }
                    } label: {
                        Circle()
                            .fill(option.color)
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                            .padding(5)
                            .overlay(Circle().stroke(option == color ? Theme.ink : .clear, lineWidth: 2))
                            .shadow(color: option.glow.opacity(option == color ? 0.5 : 0), radius: 8)
                            .frame(height: 50)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.name)
                    .accessibilityAddTraits(option == color ? .isSelected : [])
                }
            }
        }
    }

    private var wallPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Wall")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(walls) { wall in
                        Button {
                            withAnimation(Theme.spring) { wallID = wall.id }
                        } label: {
                            TagPill(text: wall.name, isSelected: wallID == wall.id)
                                .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showingNewWall = true
                    } label: {
                        TagPill(text: "+ Wall")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add wall")
                }
            }
        }
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Style", trailing: tags.isEmpty ? "Optional" : "\(tags.count) selected")
            FlowLayout(spacing: 8) {
                ForEach(StyleTag.allCases) { tag in
                    Button {
                        withAnimation(Theme.spring) {
                            if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
                        }
                    } label: {
                        TagPill(text: tag.name, isSelected: tags.contains(tag))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tags.contains(tag) ? .isSelected : [])
                }
            }
            .cruxFeedback(.selection, trigger: tags)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Details")
            VStack(spacing: 0) {
                TextField("Name (optional)", text: $name)
                    .padding(.vertical, 12)
                Divider().overlay(Theme.hairline)
                TextField("Notes, beta, sequence…", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
                    .padding(.vertical, 12)
                Divider().overlay(Theme.hairline)
                Toggle("On my tick list", isOn: $onTickList)
                    .padding(.vertical, 8)
                Toggle("Mark as project", isOn: $isProject)
                    .padding(.vertical, 8)
            }
            .glassCard(padding: 16)
        }
    }

    private var betaPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Beta", trailing: mediaItems.isEmpty ? "Optional" : "\(mediaItems.count) attached")
            PhotosPicker(selection: $mediaItems, maxSelectionCount: 6, matching: .any(of: [.images, .videos])) {
                Label("Add photos or videos", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
    }

    private var createActions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    save(log: nil)
                } label: {
                    Text("Save").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.glass)

                Button {
                    save(log: .attempt)
                } label: {
                    Text("Save & log").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.glassProminent)
            }
            .controlSize(.large)
        }
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.bottom, 8)
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .create:
            wallID = walls.first(where: { $0.id.uuidString == lastWallID })?.id ?? walls.first?.id
        case .edit(let climb):
            grade = climb.grade
            color = climb.holdColor
            wallID = climb.wall?.id
            name = climb.name
            notes = climb.notes
            tags = climb.styleTags
            onTickList = climb.isOnTickList
            isProject = climb.isProjectFlagged
        }
    }

    private func addWall() {
        let trimmed = newWallName.trimmingCharacters(in: .whitespaces)
        newWallName = ""
        guard !trimmed.isEmpty, let gym = app.currentGym else { return }
        let wall = app.addWall(named: trimmed, to: gym)
        withAnimation(Theme.spring) { wallID = wall.id }
    }

    private func save(log outcome: AttemptOutcome?) {
        let climb: Climb
        switch mode {
        case .create:
            climb = Climb(grade: grade, holdColor: color)
            context.insert(climb)
        case .edit(let existing):
            climb = existing
        }
        climb.grade = grade
        climb.holdColor = color
        climb.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        climb.notes = notes
        climb.styleTags = tags
        climb.isOnTickList = onTickList
        climb.isProjectFlagged = isProject
        climb.wall = walls.first { $0.id == wallID }
        if let wallID { lastWallID = wallID.uuidString }
        try? context.save()

        let items = mediaItems
        if !items.isEmpty {
            Task { await BetaImporter.importItems(items, into: climb, context: context) }
        }
        if let outcome {
            logger.log(outcome, on: climb)
        }
        dismiss()
    }
}
