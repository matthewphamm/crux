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
    @Environment(SessionManager.self) private var sessions
    @AppStorage("editor.lastWallID") private var lastWallID = ""

    @State private var grade: HexGrade = .three
    @State private var color: HoldColor = .blue
    @State private var wallID: UUID?
    @State private var name = ""
    @State private var notes = ""
    @State private var tags: Set<StyleTag> = []
    @State private var isProject = false
    @State private var mediaItems: [PhotosPickerItem] = []
    @State private var newWallName = ""
    @State private var showingNewWall = false
    @State private var loaded = false
    @State private var showingMore = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    hero
                    colorPicker
                    gradePicker
                    wallPicker
                    if isCreating {
                        moreToggle
                        if showingMore {
                            tagPicker
                            details
                            betaPicker
                        }
                    } else {
                        tagPicker
                        details
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.sheet)
            .scrollContentBackground(.hidden)
            .navigationTitle(isCreating ? "New climb" : "Edit climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                if !isCreating {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .buttonStyle(PillButtonStyle(filled: true))
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
        .presentationBackground(Theme.sheet)
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationDragIndicator(.visible)
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
                    .font(.system(size: 22, weight: .bold))
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
            SectionHeader(title: "Grade")
            HStack(spacing: 0) {
                ForEach(HexGrade.allCases) { option in
                    Button {
                        withAnimation(Theme.spring) { grade = option }
                    } label: {
                        VStack(spacing: 5) {
                            HexBadge(grade: option, color: option == grade ? color : .black, size: 40, glowing: option == grade)
                                .scaleEffect(option == grade ? 1.08 : 1)
                                .opacity(option == grade ? 1 : 0.55)
                            Text(option.vRange)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(option == grade ? Theme.accent : Theme.inkTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
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
            SectionHeader(title: "Hold colour", trailing: color.name)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(HoldColor.allCases) { option in
                    Button {
                        withAnimation(Theme.spring) { color = option }
                    } label: {
                        Circle()
                            .fill(option.color)
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                            .padding(5)
                            .overlay(Circle().stroke(option == color ? Theme.accent : .clear, lineWidth: 2))
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
                Toggle(isOn: $isProject) { Label("Project", systemImage: "star") }
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

    private var moreToggle: some View {
        Button {
            withAnimation(Theme.spring) { showingMore.toggle() }
        } label: {
            HStack {
                Text("Name, style, notes and beta")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary)
                    .rotationEffect(.degrees(showingMore ? 180 : 0))
            }
            .glassCard(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var createActions: some View {
        Button {
            save()
        } label: {
            Label("Add to session", systemImage: "plus")
        }
        .buttonStyle(AccentButtonStyle())
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

    private func save() {
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
        climb.isProjectFlagged = isProject
        climb.wall = walls.first { $0.id == wallID }
        if let wallID { lastWallID = wallID.uuidString }
        try? context.save()

        let items = mediaItems
        if !items.isEmpty {
            Task { await BetaImporter.importItems(items, into: climb, context: context) }
        }
        if isCreating, sessions.activeSession != nil {
            withAnimation(Theme.spring) { sessions.queue(climb) }
        }
        dismiss()
    }
}
