import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            OfferingListView()
                .tabItem {
                    Label(String(localized: "tab.offerings"), systemImage: "heart.circle.fill")
                }

            ExpenseListView()
                .tabItem {
                    Label(String(localized: "tab.expenses"), systemImage: "creditcard.fill")
                }

            ReportsHomeView()
                .tabItem {
                    Label(String(localized: "tab.reports"), systemImage: "doc.richtext.fill")
                }

            MoreView()
                .tabItem {
                    Label(String(localized: "tab.more"), systemImage: "ellipsis.circle.fill")
                }
        }
    }
}
