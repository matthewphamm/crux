import SwiftData
import SwiftUI

/// Projects, everything on the wall, and the stripped archive.
/// Grade is one tap away; everything else lives in a single Filter sheet.
struct ClimbsView: View {
    @Environment(AppModel.self) private var app
    @Query(sort: \Climb.createdAt, order: .reverse) private var allClimbs: [Climb]

    @AppStorage("climbs.segment") private var segment: ClimbSegment = .projects
    @AppStorage("climbs.sort") private var sort: ClimbSort = .grade
    @State private var filter = ClimbFilter()
    @State private var query = ""
    @State private var showingFilters = false
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Show", selection: $segment.animation(Theme.spring)) {
                        ForEach(ClimbSegment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    gradeStrip

                    if filter.sheetFilterCount > 0 { activeSummary }

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
                    .padding(.top, 4)
                    .animation(.smooth, value: results.map(\.id))

                    if results.isEmpty { empty }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 24)
                .animation(Theme.spring, value: filter)
            }
            .nightGymBackground()
            .navigationTitle("Climbs")
            .searchable(text: $query, prompt: "Search climbs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { GymSwitcher() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    filterButton
                    SettingsToolbarButton()
                }
            }
            .navigationDestination(for: Climb.self) { climb in
                ClimbDetailView(climb: climb)
                    .navigationTransition(.zoom(sourceID: climb.id, in: namespace))
            }
            .sheet(isPresented: $showingFilters) {
                ClimbFilterSheet(
                    filter: $filter,
                    sort: $sort,
                    walls: app.currentGym?.sortedWalls ?? [],
                    matchCount: results.count
                )
            }
            .cruxFeedback(.selection, trigger: filter.grades)
            .cruxFeedback(.selection, trigger: segment)
        }
    }

    private var gymClimbs: [Climb] { allClimbs.inGym(app.currentGym) }

    private var results: [Climb] {
        ClimbFilter.apply(gymClimbs, segment: segment, filter: filter, sort: sort, query: query)
    }

    // MARK: Grade strip

    /// Seven hex buttons — tap any to show just those grades.
    private var gradeStrip: some View {
        HStack(spacing: 0) {
            ForEach(HexGrade.allCases) { grade in
                let isOn = filter.grades.contains(grade)
                let dimmed = !filter.grades.isEmpty && !isOn
                Button {
                    withAnimation(Theme.spring) { filter.grades.formSymmetricDifference([grade]) }
                } label: {
                    VStack(spacing: 4) {
                        HexBadge(grade: grade, color: isOn ? .orange : .black, size: 36, glowing: isOn)
                            .scaleEffect(isOn ? 1.06 : 1)
                        Text(grade.vRange)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(isOn ? Theme.accent : Theme.inkTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .opacity(dimmed ? 0.45 : 1)
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(grade.fullLabel)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Filter button & summary

    private var filterButton: some View {
        Button {
            showingFilters = true
        } label: {
            Image(systemName: filter.sheetFilterCount > 0
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease")
        }
        .accessibilityLabel(filter.sheetFilterCount > 0 ? "Filters, \(filter.sheetFilterCount) on" : "Filters")
    }

    /// One quiet line naming the sheet filters in use, with a way out.
    private var activeSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(summaryText)
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Button("Clear") {
                withAnimation(Theme.spring) {
                    let grades = filter.grades
                    filter = ClimbFilter()
                    filter.grades = grades
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .onTapGesture { showingFilters = true }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var summaryText: String {
        let walls = (app.currentGym?.sortedWalls ?? []).filter { filter.wallIDs.contains($0.id) }.map(\.name)
        let statuses = ClimbStatus.allCases.filter { filter.statuses.contains($0) }.map(\.name)
        let colors = HoldColor.allCases.filter { filter.colors.contains($0) }.map(\.name)
        let tags = StyleTag.allCases.filter { filter.tags.contains($0) }.map(\.name)
        return (walls + statuses + colors + tags).joined(separator: " · ")
    }

    // MARK: Empty

    private var empty: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: segment == .stripped ? "archivebox" : "hexagon")
        } description: {
            Text(emptyMessage)
        }
        .padding(.top, 40)
    }

    private var isFiltering: Bool { filter.isActive || !query.isEmpty }

    private var emptyTitle: String {
        if isFiltering { return "No matches" }
        switch segment {
        case .projects: return "No projects"
        case .all: return "No climbs yet"
        case .stripped: return "Nothing stripped"
        }
    }

    private var emptyMessage: String {
        if isFiltering { return "Try fewer grades or filters." }
        switch segment {
        case .projects: return "Star a climb, or keep at one for \(Climb.projectThreshold) tries without a send."
        case .all: return "Start a session with ＋ and add the climbs you try."
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
                Text(climb.displayName)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
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
        [climb.grade.vRange, climb.wall?.name].compactMap(\.self).joined(separator: " · ")
    }
}
