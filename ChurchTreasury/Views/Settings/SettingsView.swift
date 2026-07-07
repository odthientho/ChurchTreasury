import SwiftUI

struct SettingsView: View {
    @AppStorage("churchName") private var churchName = ""
    @AppStorage("churchAddress") private var churchAddress = ""
    @AppStorage("treasurerName") private var treasurerName = ""

    // Net-asset carry anchor: the fund balance at the start of `netAssetAnchorMonth`.
    // Each month's Beginning Net Asset carries forward from here automatically.
    @AppStorage("netAssetAnchorCents") private var netAssetAnchorCents = 0
    @AppStorage("netAssetAnchorMonth") private var netAssetAnchorMonth = 0.0

    @State private var churchLogo: UIImage?
    @State private var anchorText = ""
    @State private var anchorMonth = Date().startOfMonth

    var body: some View {
        Form {
            Section(String(localized: "settings.churchInfo")) {
                TextField(String(localized: "settings.churchName"), text: $churchName)
                TextField(String(localized: "settings.churchAddress"), text: $churchAddress, axis: .vertical)
                TextField(String(localized: "settings.treasurerName"), text: $treasurerName)
            }
            Section {
                Text(String(localized: "settings.churchInfo.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text(String(localized: "settings.startingNetAsset"))
                    Spacer()
                    TextField("0.00", text: $anchorText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                        .onChange(of: anchorText) { _, newValue in
                            netAssetAnchorCents = Money.parseCents(newValue) ?? 0
                        }
                }
                DatePicker(String(localized: "settings.startingNetAssetMonth"),
                           selection: $anchorMonth, displayedComponents: .date)
                    .onChange(of: anchorMonth) { _, newValue in
                        netAssetAnchorMonth = newValue.startOfMonth.timeIntervalSince1970
                    }
            } header: {
                Text(String(localized: "settings.netAsset"))
            } footer: {
                Text(String(localized: "settings.netAsset.footer"))
            }

            PhotoAttachmentSection(titleKey: "settings.churchLogo", image: $churchLogo) { image in
                if let image {
                    ChurchLogoStore.save(image)
                } else {
                    ChurchLogoStore.delete()
                }
            }
            Section {
                Text(String(localized: "settings.churchLogo.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "more.churchInfo"))
        .onAppear {
            churchLogo = ChurchLogoStore.load()
            anchorText = netAssetAnchorCents == 0 ? ""
                : Money.formatPlain(netAssetAnchorCents).replacingOccurrences(of: ",", with: "")
            if netAssetAnchorMonth > 0 {
                anchorMonth = Date(timeIntervalSince1970: netAssetAnchorMonth)
            }
        }
    }
}
