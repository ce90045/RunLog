import Foundation

@MainActor
final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var records: [WorkoutRecord] = []
    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent("workout-history.json")
        load()
    }

    func save(_ record: WorkoutRecord) {
        records.insert(record, at: 0)
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([WorkoutRecord].self, from: data) else { return }
        records = saved.sorted { $0.startDate > $1.startDate }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
