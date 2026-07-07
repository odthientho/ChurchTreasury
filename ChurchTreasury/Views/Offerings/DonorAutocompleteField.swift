import SwiftUI

/// Donor name field with inline suggestions. Typing filters existing donors;
/// tapping one selects it. An unmatched name is left as-is and the entry flow
/// creates the donor on commit. Generic over the caller's FocusState enum so
/// it can be embedded in different entry forms.
struct DonorAutocompleteField<FocusValue: Hashable>: View {
    @Binding var text: String
    @Binding var selectedDonor: Donor?
    var donors: [Donor]
    var focus: FocusState<FocusValue?>.Binding
    var focusValue: FocusValue
    var onSelect: (Donor) -> Void

    private var suggestions: [Donor] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        if let selectedDonor, selectedDonor.name == query { return [] }
        return donors
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        TextField(String(localized: "donor.namePlaceholder"), text: $text)
            .textContentType(.name)
            .autocorrectionDisabled()
            .focused(focus, equals: focusValue)
            .onChange(of: text) { _, newValue in
                if let selectedDonor, selectedDonor.name != newValue {
                    self.selectedDonor = nil
                }
            }

        ForEach(suggestions) { donor in
            Button {
                selectedDonor = donor
                text = donor.name
                onSelect(donor)
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(.secondary)
                    Text(donor.name)
                    if let envelope = donor.envelopeNumber, !envelope.isEmpty {
                        Spacer()
                        Text("#\(envelope)")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
