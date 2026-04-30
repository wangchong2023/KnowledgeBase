import Foundation

// MARK: - Log Service (Operation Logging)
/// Manages operation log entries with persistence.
final class LogService: ObservableObject {
    @Published var logEntries: [LogEntry] = []

    private let logKey = "wikicraft_logs"
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var logsFileURL: URL {
        documentsDirectory.appendingPathComponent("wikicraft_logs.json")
    }
    
    // MARK: - Constants
    /// Maximum number of log entries to retain
    private static let maxLogEntries = 500
    
    // MARK: - Init
    init() {
        loadFromDisk()
    }

    // MARK: - Add Entry
    func addLog(action: String, target: String, details: String = "") {
        let entry = LogEntry(action: action, target: target, details: details)
        logEntries.insert(entry, at: 0)
        if logEntries.count > Self.maxLogEntries { logEntries = Array(logEntries.prefix(Self.maxLogEntries)) }
        saveToDisk()
    }

    // MARK: - Persistence
    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(logEntries)
            try data.write(to: logsFileURL, options: .atomicWrite)
        } catch {
            print(String(format: L.tr("log.error.saveFailed"), error.localizedDescription))
        }
    }

    func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: logsFileURL)
            logEntries = try decoder.decode([LogEntry].self, from: data)
        } catch {
            // Try migrating from UserDefaults
            if let data = UserDefaults.standard.data(forKey: logKey),
               let decoded = try? decoder.decode([LogEntry].self, from: data) {
                logEntries = decoded
                saveToDisk()
                UserDefaults.standard.removeObject(forKey: logKey)
            }
        }
    }
}
