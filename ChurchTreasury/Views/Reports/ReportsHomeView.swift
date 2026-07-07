import SwiftUI

struct ReportsHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "report.standardSection")) {
                    NavigationLink {
                        WeeklyReportPickerView()
                    } label: {
                        Label(String(localized: "report.weeklyReport"), systemImage: "calendar")
                    }
                    NavigationLink {
                        MonthlyReportPreviewView()
                    } label: {
                        Label(String(localized: "report.monthlyTitle"), systemImage: "doc.text")
                    } // Reconcile lives inside the monthly report (bank icon there).
                    NavigationLink {
                        GivingStatementsView()
                    } label: {
                        Label(String(localized: "report.givingStatements"), systemImage: "envelope.open")
                    }
                }

                Section(String(localized: "report.yearEnd")) {
                    NavigationLink {
                        AnnualReportPreviewView(kind: .presentation)
                    } label: {
                        Label(String(localized: "annual.presentationTitle"), systemImage: "chart.bar.xaxis")
                    }
                    NavigationLink {
                        AnnualReportPreviewView(kind: .audit)
                    } label: {
                        Label(String(localized: "annual.auditTitle"), systemImage: "doc.on.doc")
                    }
                }
            }
            // Large in-content title, matching the Offerings/Expenses tabs.
            .safeAreaInset(edge: .top, spacing: 0) {
                ScreenTitle(String(localized: "tab.reports"))
            }
            .navigationTitle(String(localized: "tab.reports"))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
