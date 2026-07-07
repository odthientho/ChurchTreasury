import SwiftUI

struct DonationEntryRow: View {
    let entry: DonationEntry

    var body: some View {
        HStack {
            Image(systemName: entry.method == .check ? "pencil.and.list.clipboard" : "envelope.fill")
                .foregroundStyle(entry.method == .check ? Color.blue : Color.teal)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.donor?.name ?? String(localized: "donor.anonymous"))
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.checkImageFilename != nil {
                Image(systemName: "camera.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(Money.format(entry.amountCents))
                .monospacedDigit()
        }
    }

    private var detailLine: String {
        var parts = [entry.method.localizedName]
        if let check = entry.checkNumber, !check.isEmpty {
            parts.append("#\(check)")
        }
        if let envelope = entry.envelopeNumber, !envelope.isEmpty {
            parts.append("#\(envelope)")
        }
        return parts.joined(separator: " · ")
    }
}
