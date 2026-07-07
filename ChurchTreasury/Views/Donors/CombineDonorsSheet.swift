import SwiftUI
import SwiftData

/// Lets the treasurer pick several donor records that are really the same
/// person (names written slightly differently on paper) and combine them into
/// one, keeping a single chosen name. All donations move to the kept donor.
struct CombineDonorsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Donor.name) private var donors: [Donor]

    /// Which name the combined donor should carry: one of the selected
    /// donors' existing names, or a brand-new one the treasurer types.
    private enum NameChoice: Hashable {
        case existing(PersistentIdentifier)
        case new
    }

    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var nameChoice: NameChoice = .new
    @State private var newName = ""
    @State private var searchText = ""

    private var selectedDonors: [Donor] {
        donors.filter { selectedIDs.contains($0.persistentModelID) }
    }

    private var filteredDonors: [Donor] {
        guard !searchText.isEmpty else { return donors }
        return donors.filter {
            $0.name.containsLoosely(searchText)
                || $0.aliases.contains { $0.containsLoosely(searchText) }
        }
    }

    /// The donor record that survives the merge (keeps its donations/history).
    /// When a new name is typed we still keep the first selected record and
    /// rename it.
    private var keeper: Donor? {
        if case .existing(let id) = nameChoice,
           let chosen = selectedDonors.first(where: { $0.persistentModelID == id }) {
            return chosen
        }
        return selectedDonors.first
    }

    /// The final real name for the combined donor.
    private var canonicalName: String {
        switch nameChoice {
        case .existing(let id):
            return selectedDonors.first { $0.persistentModelID == id }?.name ?? ""
        case .new:
            return newName.trimmingCharacters(in: .whitespaces)
        }
    }

    private var canCombine: Bool {
        selectedIDs.count >= 2 && keeper != nil && !canonicalName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "donor.combineInstructions"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if selectedIDs.count >= 2 {
                    Section {
                        Picker(String(localized: "donor.combineKeep"), selection: $nameChoice) {
                            ForEach(selectedDonors) { donor in
                                Text(donor.name).tag(NameChoice.existing(donor.persistentModelID))
                            }
                            Text(String(localized: "donor.newName"))
                                .tag(NameChoice.new)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()

                        if case .new = nameChoice {
                            TextField(String(localized: "donor.newNamePlaceholder"), text: $newName)
                                .textInputAutocapitalization(.words)
                        }
                    } header: {
                        Text(String(localized: "donor.combineKeep"))
                    }
                }

                Section(String(localized: "donor.combineSelect")) {
                    ForEach(filteredDonors) { donor in
                        Button {
                            toggle(donor)
                        } label: {
                            HStack {
                                Image(systemName: selectedIDs.contains(donor.persistentModelID)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(donor.persistentModelID)
                                                     ? Color.accentColor : Color.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(donor.name)
                                        .foregroundStyle(.primary)
                                    let count = donor.donations?.count ?? 0
                                    if count > 0 {
                                        Text(String(format: String(localized: "donor.giftCount"), count))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: String(localized: "donors.search"))
            .navigationTitle(String(localized: "donor.combineTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "donor.combineAction")) { combine() }
                        .disabled(!canCombine)
                }
            }
        }
    }

    private func toggle(_ donor: Donor) {
        let id = donor.persistentModelID
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            if case .existing(id) = nameChoice { nameChoice = .new }
        } else {
            selectedIDs.insert(id)
            // Default to keeping the first name picked, so the common case
            // (pick two, keep one) needs no extra taps.
            if selectedIDs.count == 1 { nameChoice = .existing(id) }
        }
    }

    private func combine() {
        guard let keeper else { return }
        let duplicates = selectedDonors.filter { $0.persistentModelID != keeper.persistentModelID }
        DonorMerger.merge(into: keeper, duplicates: duplicates,
                          canonicalName: canonicalName, context: context)
        dismiss()
    }
}
