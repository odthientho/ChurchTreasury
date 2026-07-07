import SwiftUI
import SwiftData

struct DonorDetailView: View {
    @Bindable var donor: Donor
    @Environment(\.modelContext) private var context

    /// Donations grouped by year, newest year first.
    private var donationsByYear: [(year: Int, total: Int, entries: [DonationEntry])] {
        let donations = (donor.donations ?? []).filter { $0.batch != nil }
        let grouped = Dictionary(grouping: donations) { entry in
            Calendar.current.component(.year, from: entry.batch?.serviceDate ?? entry.createdAt)
        }
        return grouped
            .map { year, entries in
                (year: year,
                 total: entries.reduce(0) { $0 + $1.amountCents },
                 entries: entries.sorted {
                     ($0.batch?.serviceDate ?? .distantPast) > ($1.batch?.serviceDate ?? .distantPast)
                 })
            }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        List {
            Section {
                TextField(String(localized: "donor.name"), text: $donor.name)
                TextField(
                    String(localized: "donor.realName"),
                    text: Binding(
                        get: { donor.realName ?? "" },
                        set: { donor.realName = $0.isEmpty ? nil : $0 }
                    )
                )
            } header: {
                Text(String(localized: "donor.info"))
            } footer: {
                Text(String(localized: "donor.realName.footer"))
            }

            Section {
                TextField(
                    String(localized: "field.envelopeNumber"),
                    text: Binding(
                        get: { donor.envelopeNumber ?? "" },
                        set: { donor.envelopeNumber = $0.isEmpty ? nil : $0 }
                    )
                )
                .keyboardType(.numberPad)
                TextField(
                    String(localized: "donor.address"),
                    text: Binding(
                        get: { donor.address ?? "" },
                        set: { donor.address = $0.isEmpty ? nil : $0 }
                    ),
                    axis: .vertical
                )
                TextField(
                    String(localized: "donor.phone"),
                    text: Binding(
                        get: { donor.phone ?? "" },
                        set: { donor.phone = $0.isEmpty ? nil : $0 }
                    )
                )
                .keyboardType(.phonePad)
            }

            if !donor.aliases.isEmpty {
                Section {
                    ForEach(donor.aliases, id: \.self) { alias in
                        Text(alias)
                    }
                    .onDelete { offsets in
                        donor.aliases.remove(atOffsets: offsets)
                    }
                } header: {
                    Text(String(localized: "donor.otherNames"))
                } footer: {
                    Text(String(localized: "donor.otherNamesNote"))
                }
            }

            ForEach(donationsByYear, id: \.year) { group in
                Section {
                    ForEach(group.entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if let date = entry.batch?.serviceDate {
                                    Text(date, format: .dateTime.month().day().year())
                                }
                                Text(entry.method.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.format(entry.amountCents))
                                .monospacedDigit()
                        }
                    }
                } header: {
                    HStack {
                        Text(String(group.year))
                        Spacer()
                        Text(Money.format(group.total))
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(donor.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }
}
