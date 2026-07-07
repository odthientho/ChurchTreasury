import SwiftUI

/// One row of the loose-cash denomination tally: how many bills of this
/// value, with the running subtotal shown alongside.
struct BillCountRow: View {
    let denomination: BillDenomination
    @Binding var count: Int
    var focus: FocusState<BillDenomination?>.Binding

    // Derived directly from `count` on every read rather than cached in
    // local @State — a plain @State copy only syncs once on first appear,
    // so it goes stale when `count` changes for a reason other than typing
    // in this field (e.g. resolving to an existing batch after the row
    // already appeared, as happens when resuming a deposited collection).
    private var text: Binding<String> {
        Binding(
            get: { count == 0 ? "" : String(count) },
            set: { newValue in
                let filtered = newValue.filter(\.isNumber)
                count = Int(filtered) ?? 0
            }
        )
    }

    var body: some View {
        HStack {
            Text(denomination.label)
                .frame(width: 44, alignment: .leading)

            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .focused(focus, equals: denomination)

            Text(String(localized: "offering.billsSuffix"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(Money.format(denomination.rawValue * count * 100))
                .monospacedDigit()
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
    }
}
