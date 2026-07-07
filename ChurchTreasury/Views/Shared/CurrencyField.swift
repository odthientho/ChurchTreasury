import SwiftUI

/// A right-aligned dollar entry field bound to integer cents.
/// Parses as the user types; invalid text leaves the last good value.
struct CurrencyField: View {
    let titleKey: String
    @Binding var cents: Int
    /// Grabs keyboard focus shortly after appearing — for screens that jump
    /// straight into this field (e.g. the loose-cash quick-entry button).
    var autofocus: Bool = false
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(String(localized: String.LocalizationValue(titleKey)))
            Spacer()
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
                .focused($isFocused)
                .onAppear {
                    if cents != 0 { text = Money.formatPlain(cents).replacingOccurrences(of: ",", with: "") }
                    if autofocus {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isFocused = true }
                    }
                }
                .onChange(of: text) { _, newValue in
                    if newValue.isEmpty {
                        cents = 0
                    } else if let parsed = Money.parseCents(newValue) {
                        cents = parsed
                    }
                }
        }
    }
}
