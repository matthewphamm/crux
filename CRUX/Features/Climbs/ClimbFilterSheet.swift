import SwiftUI

/// Everything except grade and search, tucked into one calm sheet.
struct ClimbFilterSheet: View {
    @Binding var filter: ClimbFilter
    @Binding var sort: ClimbSort
    let walls: [Wall]
    let matchCount: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    section("Sort by") {
                        Picker("Sort by", selection: $sort.animation(.smooth)) {
                            ForEach(ClimbSort.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if !walls.isEmpty {
                        section("Wall") {
                            FlowLayout(spacing: 8) {
                                ForEach(walls) { wall in
                                    pill(wall.name, isOn: filter.wallIDs.contains(wall.id)) {
                                        filter.wallIDs.formSymmetricDifference([wall.id])
                                    }
                                }
                            }
                        }
                    }

                    section("Status") {
                        FlowLayout(spacing: 8) {
                            ForEach(ClimbStatus.allCases) { status in
                                pill(status.name, isOn: filter.statuses.contains(status)) {
                                    filter.statuses.formSymmetricDifference([status])
                                }
                            }
                        }
                    }

                    section("Hold color") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                            ForEach(HoldColor.allCases) { color in
                                let isOn = filter.colors.contains(color)
                                Button {
                                    withAnimation(Theme.spring) { filter.colors.formSymmetricDifference([color]) }
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                                        .padding(4)
                                        .overlay(Circle().stroke(isOn ? Theme.ink : .clear, lineWidth: 2))
                                        .frame(height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(color.name)
                                .accessibilityAddTraits(isOn ? .isSelected : [])
                            }
                        }
                    }

                    section("Style") {
                        FlowLayout(spacing: 8) {
                            ForEach(StyleTag.allCases) { tag in
                                pill(tag.name, isOn: filter.tags.contains(tag)) {
                                    filter.tags.formSymmetricDifference([tag])
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .nightGymBackground()
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        withAnimation(Theme.spring) {
                            let grades = filter.grades
                            filter = ClimbFilter()
                            filter.grades = grades
                            sort = .grade
                        }
                    }
                    .disabled(filter.sheetFilterCount == 0 && sort == .grade)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(matchCount == 1 ? "Show 1 climb" : "Show \(matchCount) climbs") { dismiss() }
                        .buttonStyle(.glassProminent)
                        .contentTransition(.numericText(value: Double(matchCount)))
                }
            }
            .cruxFeedback(.selection, trigger: filter)
            .cruxFeedback(.selection, trigger: sort)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: title)
            content()
        }
    }

    private func pill(_ title: String, isOn: Bool, toggle: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.spring, toggle)
        } label: {
            TagPill(text: title, isSelected: isOn)
                .font(.subheadline)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
