import Foundation
import Combine

class PersistenceManager: ObservableObject {
    static let shared = PersistenceManager()
    private let storageKey = "gaia_scan_history"

    @Published var scanHistory: [ScanEntry] = []

    private init() {
        loadHistory()
    }

    func save(entry: ScanEntry) {
        scanHistory.insert(entry, at: 0)
        persistHistory()
    }

    func delete(entry: ScanEntry) {
        scanHistory.removeAll { $0.id == entry.id }
        persistHistory()
    }

    func clearAll() {
        scanHistory.removeAll()
        persistHistory()
    }

    private func persistHistory() {
        if let data = try? JSONEncoder().encode(scanHistory) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([ScanEntry].self, from: data) else { return }
        scanHistory = entries
    }
}
