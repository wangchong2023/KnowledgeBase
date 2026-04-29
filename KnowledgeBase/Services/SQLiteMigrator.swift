import Foundation
import SQLite3

// MARK: - SQLite Migrator (JSON → SQLite Migration)
/// Handles one-time migration from legacy JSON file storage to SQLite.
/// Runs automatically on first launch if the legacy JSON file exists.
final class SQLiteMigrator {
    private let core: SQLiteStoreCore
    private let jsonURL: URL

    init(core: SQLiteStoreCore, docsDir: URL) {
        self.core = core
        self.jsonURL = docsDir.appendingPathComponent("wikicraft_pages.json")
    }

    /// Returns true if JSON file exists and DB is empty (needs migration).
    var needsMigration: Bool {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else { return false }
        return core.countPages() == 0
    }

    /// Run migration from legacy JSON file.
    /// Does nothing if no migration is needed.
    func migrateIfNeeded() {
        guard needsMigration else { return }

        print("[SQLiteMigrator] Migrating from JSON file...")

        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyPages = try decoder.decode([WikiPage].self, from: data)

            core.beginTransaction()
            for page in legacyPages {
                core.insertPage(page)
            }
            core.commitTransaction()

            print("[SQLiteMigrator] Migrated \(legacyPages.count) pages")

            // Keep JSON as backup (rename)
            try? FileManager.default.moveItem(
                at: jsonURL,
                to: jsonURL.appendingPathExtension("migrated")
            )
        } catch {
            print("[SQLiteMigrator] Migration failed: \(error.localizedDescription)")
        }
    }
}
