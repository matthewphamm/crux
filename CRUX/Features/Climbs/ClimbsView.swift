import SwiftData
import SwiftUI

/// Tick list, projects, everything on the wall, and the stripped archive — with filters.
struct ClimbsView: View {
    @Environment(AppModel.self) private var app
    @Query(sort: \Climb.createdAt, order: .reverse) private var allClimbs: [Climb]

    @AppStorage("climbs.segment") private var segment: ClimbSegment = .tickList
    @AppStorage("climbs.sort") private var sort: ClimbSort = .grade
    @State private var filter = ClimbFilter()
    @State private var query = ""
    @State private var showingNewClimb = false
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Segment", selection: $segment.animation(Theme.spring)) {
                        ForEach(ClimbSegment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    filterBar

                    LazyVStack(spacing: 10) {
                        ForEach(results) { climb in
                            NavigationLink(value: climb) {
                                ClimbRow(climb: climb)
                                    .matchedTransitionSource(id: climb.id, in: namespace)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .animation(.smooth, value: results.map(\.id))

                    if results.isEmpty { empty }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 24)
            }
            .nightGymBackground()
            .navigationTitle("Climbs")
            .searchable(text: $query, prompt: "Search climbs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { sortMenu }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("New climb", systemImage: "plus") { showingNewClimb = true }
                    SettingsToolbarButton()
                }
            }
            .navigationDestination(for: Climb.self) { climb in
                ClimbDetailView(climb: climb)
                    .navigationTransition(.zoom(sourceID: climb.id, in: namespace))
            }
            .sheet(isPresented: $showingNewClimb) { ClimbEditorSheet(mode: .create) }
            .cruxFeedback(.selection, trigger: filter)
            .cruxFeedback(.selection, trigger: segment)
        }
    }

    private var gymClimbs: [Climb] { allClimbs.inGym(app.currentGym) }

    private var results: [Climb] {
        ClimbFilter.apply(gymClimbs, segment: segment, filter: filter, sort: sort, query: query)
    }

    // MARK: Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    gradeMenu
                    wallMenu
                    colorMenu
                    statusMenu
                    tagMenu
                    if filter.isActive {
                        Button {
                            withAnimation(Theme.spring) { filter = ClimbFilter() }
                        } label: {
                            Label("Clear", systemImage: "xmark")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
        .animation(Theme.spring, value: filter)
    }

    private var gradeMenu: some View {
        Menu {
            Picker("Lowest", selection: $filter.minGrade) {
                ForEach(HexGrade.allCases.filter { $0 <= filter.maxGrade }) { Text($0.fullLabel).tag($0) }
            }
            .pickerStyle(.menu)
            Picker("Highest", selection: $filter.maxGrade) {
                ForEach(HexGrade.allCases.filter { $0 >= filter.minGrade }) { Text($0.fullLabel).tag($0) }
            }
            .pickerStyle(.menu)
        } label: {
            FilterChip(
                title: "Grade",
                value: filter.hasGradeRange ? gradeRangeLabel : nil,
                isActive: filter.hasGradeRange,
                symbol: "hexagon"
            )
        }
    }

    private var gradeRangeLabel: String {
        filter.minGrade == filter.maxGrade
            ? filter.minGrade.label
            : "\(filter.minGrade.rawValue)–\(filter.maxGrade.rawValue) Hex"
    }

    private var wallMenu: some View {
        Menu {
            Picker("Wall", selection: $filter.wallID) {
                Text("Any wall").tag(UUID?.none)
                ForEach(app.currentGym?.sortedWalls ?? []) { Text($0.name).tag(Optional($0.id)) }
            }
        } label: {
            FilterChip(
                title: "Wall",
                value: app.currentGym?.sortedWalls.first { $0.id == filter.wallID }?.name,
                isActive: filter.wallID != nil
            )
        }
    }

    private var colorMenu: some View {
        Menu {
            ForEach(HoldColor.allCases) { color in
                Toggle(color.name, isOn: binding(for: color, in: \.colors))
            }
        } label: {
            FilterChip(title: "Color", value: setLabel(filter.colors.map(\.name)), isActive: !filter.colors.isEmpty)
        }
        .menuActionDismissBehavior(.disabled)
    }

    private var statusMenu: some View {
        Menu {
            ForEach(ClimbStatus.allCases) { status in
                Toggle(isOn: binding(for: status, in: \.statuses)) { Label(status.name, systemImage: status.symbol) }
            }
        } label: {
            FilterChip(title: "Status", value: setLabel(filter.statuses.map(\.name)), isActive: !filter.statuses.isEmpty)
        }
        .menuActionDismissBehavior(.disabled)
    }

    private var tagMenu: some View {
        Menu {
            ForEach(StyleTag.allCases) { tag in
                Toggle(tag.name, isOn: binding(for: tag, in: \.tags))
            }
        } label: {
            FilterChip(title: "Style", value: setLabel(filter.tags.map(\.name)), isActive: !filter.tags.isEmpty)
        }
        .menuActionDismissBehavior(.disabled)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sort.animation(.smooth)) {
                ForEach(ClimbSort.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    private func setLabel(_ names: [String]) -> String? {
        switch names.count {
        case 0: nil
        case 1: names[0]
        default: "\(names.count) selected"
        }
    }

    private func binding<T: Hashable>(for value: T, in keyPath: WritableKeyPath<ClimbFilter, Set<T>>) -> Binding<Bool> {
        Binding {
            filter[keyPath: keyPath].contains(value)
        } set: { isOn in
            withAnimation(Theme.spring) {
                if isOn { filter[keyPath: keyPath].insert(value) } else { filter[keyPath: keyPath].remove(value) }
            }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: segment == .stripped ? "archivebox" : "hexagon")
        } description: {
            Text(emptyMessage)
        }
        .padding(.top, 40)
    }

    private var emptyTitle: String {
        if filter.isActive || !query.isEmpty { return "No matches" }
        switch segment {
        case .tickList: return "Tick list is empty"
        case .projects: return "No projects"
        case .all: return "No climbs yet"
        case .stripped: return "Nothing stripped"
        }
    }

    private var emptyMessage: String {
        if filter.isActive || !query.isEmpty { return "Try loosening your filters." }
        switch segment {
        case .tickList: return "Add climbs you want to send to your tick list."
        case .projects: return "Climbs become projects after \(Climb.projectThreshold) tries without a send, or when you flag them."
        case .all: return "Add a climb to start logging."
        case .stripped: return "When you mark a wall reset, its climbs are archived here with their history."
        }
    }
}

struct ClimbRow: View {
    let climb: Climb

    var body: some View {
        HStack(spacing: 14) {
            HexBadge(grade: climb.grade, color: climb.holdColor, size: 44, glowing: climb.status.isTopped)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(climb.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if climb.isOnTickList {
                        Image(systemName: climb.hasSent ? "checkmark.seal.fill" : "bookmark.fill")
                            .font(.caption)
                            .foregroundStyle(climb.hasSent ? Theme.send : Theme.accent)
                            .accessibilityLabel(climb.hasSent ? "Ticked" : "On tick list")
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                StatusLabel(status: climb.status)
                Text(climb.tryCount == 1 ? "1 try" : "\(climb.tryCount) tries")
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .glassCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = [climb.grade.vRange]
        if let wall = climb.wall?.name { parts.append(wall) }
        let tags = climb.styleTags.map(\.name).sorted().filter { $0.caseInsensitiveCompare(climb.wall?.name ?? "") != .orderedSame }
        if let tag = tags.first { parts.append(tag) }
        return parts.joined(separator: " · ")
    }
}
