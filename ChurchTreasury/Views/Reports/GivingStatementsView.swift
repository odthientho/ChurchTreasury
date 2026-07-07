import SwiftUI
import SwiftData

struct GivingStatementsView: View {
    @Query(sort: \Donor.name) private var donors: [Donor]

    @AppStorage("churchName") private var churchName = ""
    @AppStorage("churchAddress") private var churchAddress = ""
    @AppStorage("treasurerName") private var treasurerName = ""

    @State private var selectedYear = Calendar.current.component(.year, from: Date()) - 1
    @State private var previewStatement: GivingStatementData?

    private var church: ChurchInfo {
        ChurchInfo(name: churchName, address: churchAddress, treasurerName: treasurerName,
                   logoPNG: ChurchLogoStore.pngData())
    }

    private var statements: [GivingStatementData] {
        ReportDataBuilder.givingStatements(year: selectedYear, church: church, donors: donors)
    }

    var body: some View {
        List {
            Section {
                Picker(String(localized: "giving.year"), selection: $selectedYear) {
                    let currentYear = Calendar.current.component(.year, from: Date())
                    ForEach(((currentYear - 6)...currentYear).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }

                if !statements.isEmpty {
                    ShareLink(
                        item: ReportFile.url(
                            for: GivingStatementPDF.renderAll(statements),
                            named: "giving-statements-\(selectedYear)"
                        )
                    ) {
                        Label(String(localized: "giving.exportAll \(statements.count)"),
                              systemImage: "square.and.arrow.up")
                    }
                }
            }

            if statements.isEmpty {
                ContentUnavailableView(
                    String(localized: "giving.empty.title"),
                    systemImage: "envelope.open",
                    description: Text(String(localized: "giving.empty.description"))
                )
            } else {
                Section(String(localized: "more.donors")) {
                    ForEach(statements, id: \.donorName) { statement in
                        Button {
                            previewStatement = statement
                        } label: {
                            HStack {
                                Text(statement.donorName)
                                Spacer()
                                Text(Money.format(statement.totalCents))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "report.givingStatements"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewStatement) { statement in
            NavigationStack {
                PDFPreview(data: GivingStatementPDF.render(statement))
                    .navigationTitle(statement.donorName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            ShareLink(item: ReportFile.url(
                                for: GivingStatementPDF.render(statement),
                                named: "giving-\(selectedYear)-\(statement.donorName.replacingOccurrences(of: " ", with: "-"))"
                            ))
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "action.done")) {
                                previewStatement = nil
                            }
                        }
                    }
            }
        }
    }
}

extension GivingStatementData: Identifiable {
    var id: String { donorName }
}
