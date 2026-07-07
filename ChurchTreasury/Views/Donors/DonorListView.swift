import SwiftUI
import SwiftData

struct DonorListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Donor.name) private var donors: [Donor]
    @State private var searchText = ""
    @State private var showingNewDonor = false
    @State private var showingCombine = false

    private var filteredDonors: [Donor] {
        guard !searchText.isEmpty else { return donors }
        // Accent-insensitive so "Nguyen" finds "Nguyễn". The list still shows
        // only the main name; aliases just widen what a search matches.
        return donors.filter {
            $0.name.containsLoosely(searchText)
                || ($0.realName ?? "").containsLoosely(searchText)
                || $0.aliases.contains { $0.containsLoosely(searchText) }
        }
    }

    var body: some View {
        Group {
            if donors.isEmpty {
                ContentUnavailableView(
                    String(localized: "donors.empty.title"),
                    systemImage: "person.2",
                    description: Text(String(localized: "donors.empty.description"))
                )
            } else {
                List {
                    ForEach(filteredDonors) { donor in
                        NavigationLink(destination: DonorDetailView(donor: donor)) {
                            HStack {
                                // Only the real name is shown in the list; the
                                // alternate spellings appear inside the donor's
                                // detail ("Other names"), not here.
                                Text(donor.name)
                                Spacer()
                                if let envelope = donor.envelopeNumber, !envelope.isEmpty {
                                    Text("#\(envelope)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteDonors)
                }
                .searchable(text: $searchText, prompt: String(localized: "donors.search"))
            }
        }
        .navigationTitle(String(localized: "more.donors"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if donors.count >= 2 {
                    Button {
                        showingCombine = true
                    } label: {
                        Label(String(localized: "donor.combine"),
                              systemImage: "arrow.triangle.merge")
                    }
                    .accessibilityLabel(String(localized: "donor.combineTitle"))
                }
                Button {
                    showingNewDonor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "donor.new"))
            }
        }
        .sheet(isPresented: $showingNewDonor) {
            NewDonorSheet()
        }
        .sheet(isPresented: $showingCombine) {
            CombineDonorsSheet()
        }
    }

    private func deleteDonors(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredDonors[index])
        }
        try? context.save()
    }
}

private struct NewDonorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var envelopeNumber = ""
    @State private var address = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "donor.name"), text: $name)
                TextField(String(localized: "field.envelopeNumber"), text: $envelopeNumber)
                    .keyboardType(.numberPad)
                TextField(String(localized: "donor.address"), text: $address, axis: .vertical)
                TextField(String(localized: "donor.phone"), text: $phone)
                    .keyboardType(.phonePad)
            }
            .navigationTitle(String(localized: "donor.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) {
                        let donor = Donor(
                            name: name.trimmingCharacters(in: .whitespaces),
                            envelopeNumber: envelopeNumber.isEmpty ? nil : envelopeNumber,
                            address: address.isEmpty ? nil : address,
                            phone: phone.isEmpty ? nil : phone
                        )
                        context.insert(donor)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
