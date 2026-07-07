import SwiftUI
import SwiftData

@main
struct ChurchTreasuryApp: App {
    let container: ModelContainer

    /// Local-only, on purpose — no iCloud/CloudKit sync. All app data (this
    /// database plus `AttachmentStore`'s photos) lives under `Documents/` so
    /// the entire folder can be handed off in one piece (via the Files app,
    /// AirDrop, or Finder file sharing) when the church's treasurer changes,
    /// instead of depending on the outgoing treasurer's iCloud account.
    private static var storeURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("ChurchTreasuryData.store")
    }

    init() {
        // UI tests pass this to start from a clean database each run —
        // without it, tests sharing one simulator install can pollute each
        // other's data (e.g. one test's collection for "this Sunday" still
        // being there, and already deposited, when the next test expects
        // an empty slate).
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset") {
            Self.resetPersistentStore()
        }

        let schema = Schema([
            Donor.self,
            OfferingBatch.self,
            DonationEntry.self,
            ExpenseEntry.self,
            RecurringExpense.self,
            ReimbursementRequest.self,
            Category.self,
            ReconciliationPeriod.self,
            BankStatementImport.self,
            BankTransaction.self,
        ])
        do {
            let config = ModelConfiguration(schema: schema, url: Self.storeURL, cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    #if DEBUG
                    MockDataSeeder.seedIfRequested(context: container.mainContext)
                    TouchIndicator.enableIfRequested()
                    #endif
                    CategorySeeder.seedIfNeeded(context: container.mainContext)
                }
        }
        .modelContainer(container)
    }

    private static func resetPersistentStore() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: documents, includingPropertiesForKeys: nil
        )) ?? []
        for url in contents where url.lastPathComponent.hasPrefix("ChurchTreasuryData.store") {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
