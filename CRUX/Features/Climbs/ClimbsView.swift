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
                    searchRow

                    CruxSegmented(options: ClimbSegment.allCases, selection: $segment) { $0.rawValue }

                    gradeStrip

                    if filter.sheetFilterCount > 0 { activeSummary }

                    if segment == .stripped && !results.isEmpty { strippedNote }

                    LazyVStack(spacing: 8) {
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
            .cruxTabBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { GymSwitcher() }
                ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() }
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
            .onChange(of: app.currentGym?.id) {
                filter = ClimbFilter()
                query = ""
            }
        }
    }

    private var gymClimbs: [Climb] { allClimbs.inGym(app.currentGym) }

    private var results: [Climb] {
        ClimbFilter.apply(gymClimbs, segment: segment, filter: filter, sort: sort, query: query)
    }

    // MARK: Grade strip

    /// Seven hex buttons with a count bar above each — tap any to show just those grades.
    private var gradeStrip: some View {
        let counts = gradeCounts
        let peak = max(counts.values.max() ?? 0, 1)
        return HStack(spacing: 0) {
            ForEach(HexGrade.allCases) { grade in
                let isOn = filter.grades.contains(grade)
                let dimmed = !filter.grades.isEmpty && !isOn
                let count = counts[grade.rawValue] ?? 0
                Button {
                    withAnimation(Theme.spring) { filter.grades.formSymmetricDifference([grade]) }
                } label: {
                    VStack(spacing: 5) {
                        Capsule()
                            .fill(isOn ? Theme.accent : Theme.inkTertiary)
                            .frame(width: 4, height: 2 + 20 * CGFloat(count) / CGFloat(peak))
                            .frame(height: 22, alignment: .bottom)
                        HexBadge(grade: grade, color: isOn ? .orange : .black, size: 38, glowing: isOn)
                        Text(grade.vRange)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isOn ? Theme.accent : Theme.inkTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .opacity(dimmed ? 0.45 : 1)
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(grade.fullLabel), \(count) climbs")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    /// Climbs per grade in the current segment (before the grade filter).
    private var gradeCounts: [Int: Int] {
        var unfiltered = filter
        unfiltered.grades = []
        let pool = ClimbFilter.apply(gymClimbs, segment: segment, filter: unfiltered, sort: sort, query: query)
        return Dictionary(grouping: pool, by: \.gradeValue).mapValues(\.count)
    }

    // MARK: Search

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkTertiary)
                TextField("Search climbs", text: $query)
                    .font(.system(size: 16))
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkTertiary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .controlBackground(Capsule())

            filterButton
        }
    }

    // MARK: Filter button & summary

    private var filterButton: some View {
        let count = filter.sheetFilterCount
        return Button {
            showingFilters = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.number(size: 14, weight: .bold))
                }
            }
            .foregroundStyle(count > 0 ? Theme.accent : Theme.ink)
            .padding(.horizontal, count > 0 ? 12 : 0)
            .frame(minWidth: 38, minHeight: 38)
            .controlBackground(Capsule())
            .overlay {
                if count > 0 {
                    Capsule().strokeBorder(Theme.accent, lineWidth: 1.5).padding(1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0 ? "Filters, \(count) on" : "Filters")
    }

    /// One quiet line naming the sheet filters in use, with a way out.
    private var activeSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(summaryText)
                .font(.system(size: 13))
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
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .controlBackground(Capsule())
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

    private var strippedNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(Theme.stripped)
            Text("No longer on the wall. Their logs, beta and stats are kept.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.danger.opacity(0.10), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.danger.opacity(0.25), lineWidth: 1))
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
            HexBadge(grade: climb.grade, color: climb.holdColor, size: 44,
                     glowing: climb.isActive && (climb.status.isTopped || climb.status == .project),
                     dim: !climb.isActive)
            VStack(alignment: .leading, spacing: 3) {
                Text(climb.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(climb.isActive ? Theme.ink : Theme.inkSecondary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(climb.isActive ? Theme.inkSecondary : Theme.inkTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                if let strippedAt = climb.strippedAt {
                    StrippedTag(date: strippedAt)
                } else {
                    StatusLabel(status: climb.status)
                }
                Text(Format.tries(climb.tryCount))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .glassCard(padding: 14, tint: climb.isActive ? nil : Theme.danger.opacity(0.5))
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        [climb.grade.vRange, climb.wall?.name].compactMap(\.self).joined(separator: " · ")
    }
}

/// Red "Stripped · Oct 9" marker for climbs that are off the wall.
struct StrippedTag: View {
    let date: Date

    var body: some View {
        Label {
            Text("Stripped · \(date.formatted(.dateTime.month(.abbreviated).day()))")
        } icon: {
            Image(systemName: "archivebox")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Theme.danger)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .fixedSize()
        .accessibilityLabel("Stripped on \(date.formatted(date: .long, time: .omitted))")
    }
}
