import SwiftUI

struct MoreView: View {
    // Only one About topic is open at a time (opening one closes the others).
    @State private var expandedTopic: HelpTopic.ID?

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "more.section.settings")) {
                    NavigationLink(destination: DonorListView()) {
                        Label(String(localized: "more.donors"), systemImage: "person.2.fill")
                    }
                    NavigationLink(destination: CategoryManagementView()) {
                        Label(String(localized: "more.categories"), systemImage: "folder.fill")
                    }
                    NavigationLink(destination: RecurringExpensesView()) {
                        Label(String(localized: "more.recurring"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink(destination: SettingsView()) {
                        Label(String(localized: "more.churchInfo"), systemImage: "building.columns.fill")
                    }
                }

                Section(String(localized: "more.section.about")) {
                    ForEach(HelpContent.topics) { topic in
                        DisclosureGroup(isExpanded: expansion(of: topic.id)) {
                            Text(topic.answer)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } label: {
                            Label(topic.question, systemImage: topic.icon)
                                .font(.callout.weight(.medium))
                        }
                    }
                }
            }
            // Large in-content title (like Offerings/Expenses); bar hidden but
            // title kept so pushed screens get a proper "‹ More" back button.
            .safeAreaInset(edge: .top, spacing: 0) {
                ScreenTitle(String(localized: "tab.more"))
            }
            .navigationTitle(String(localized: "tab.more"))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// Binding that keeps a single About topic open: opening one collapses
    /// whichever was open before.
    private func expansion(of id: HelpTopic.ID) -> Binding<Bool> {
        Binding(
            get: { expandedTopic == id },
            set: { isOpen in
                withAnimation { expandedTopic = isOpen ? id : nil }
            }
        )
    }
}

/// A large in-content screen title pinned above a List, matching the Offerings
/// and Expenses tabs.
struct ScreenTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        HStack {
            Text(title).font(.largeTitle.bold())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.systemGroupedBackground))
    }
}
