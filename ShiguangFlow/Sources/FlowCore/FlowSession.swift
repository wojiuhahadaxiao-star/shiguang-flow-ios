import Foundation

public struct PhotoRecord: Equatable {
    public let id: String
    public let date: Date?
    public init(id: String, date: Date?) { self.id = id; self.date = date }
}

/// All state mutations occur on the UI thread. No image data lives in this model.
public final class FlowSession {
    public enum Mode: Equatable { case random, day(Date) }
    public private(set) var records: [PhotoRecord] = []
    public private(set) var mode: Mode = .random
    public private(set) var page = 0
    public private(set) var randomIDs: [String] = []
    public private(set) var pending: [String] = []
    public let pageSize = 25
    private let calendar: Calendar
    private var randomGroups: [[String]] = []
    private var randomGroupIndex = 0
    public var groupNumber: Int { if case .random = mode { return randomGroupIndex + 1 }; return page + 1 }
    private var randomAnchor: String?
    private var dayIDs: [Date: [String]] = [:]
    private struct UndoEntry {
        let id: String
        let mode: Mode
        let page: Int
        let randomIDs: [String]
        let randomGroups: [[String]]
        let randomGroupIndex: Int
    }
    private var history: [UndoEntry] = []
    public init(calendar: Calendar = .current, pending: [String] = []) {
        self.calendar = calendar
        var seen = Set<String>()
        self.pending = pending.filter { seen.insert($0).inserted }
    }
    public var canUndo: Bool { !history.isEmpty || !pending.isEmpty }
    public var allModeIDs: [String] {
        let hidden = Set(pending)
        switch mode {
        case .random: return randomIDs.filter { !hidden.contains($0) }
        case .day(let day):
            return (dayIDs[calendar.startOfDay(for: day)] ?? []).filter { !hidden.contains($0) }
        }
    }
    public var visibleIDs: [String] {
        let ids = allModeIDs
        if case .random = mode { return Array(ids.prefix(pageSize)) }
        let start = min(page * pageSize, ids.count)
        return Array(ids[start..<min(start + pageSize, ids.count)])
    }
    private func available(_ ids: [String]) -> Bool { ids.contains { !pending.contains($0) } }
    private var previousRandomIndex: Int? {
        guard randomGroupIndex > 0 else { return nil }
        return (0..<randomGroupIndex).reversed().first { available(randomGroups[$0]) }
    }
    private var nextRandomIndex: Int? {
        guard randomGroupIndex + 1 < randomGroups.count else { return nil }
        return ((randomGroupIndex + 1)..<randomGroups.count).first { available(randomGroups[$0]) }
    }
    public var hasPrevious: Bool { if case .random = mode { return previousRandomIndex != nil }; return page > 0 }
    public var hasNext: Bool {
        if case .random = mode {
            if nextRandomIndex != nil { return true }
            let excluded = Set(pending + randomIDs)
            return records.contains { !excluded.contains($0.id) }
        }
        return (page + 1) * pageSize < allModeIDs.count
    }
    public func update(_ records: [PhotoRecord]) {
        self.records = records.sorted {
            let lhs = $0.date ?? .distantPast, rhs = $1.date ?? .distantPast
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
        dayIDs.removeAll(keepingCapacity: true)
        for record in self.records {
            if let date = record.date { dayIDs[calendar.startOfDay(for: date), default: []].append(record.id) }
        }
        let valid = Set(records.map(\.id))
        pending.removeAll { !valid.contains($0) }
        randomIDs.removeAll { !valid.contains($0) }
        randomGroups = randomGroups.map { $0.filter { valid.contains($0) } }
        history.removeAll { !valid.contains($0.id) }
        if randomIDs.isEmpty { newRandomBatch() }
        clampPage()
    }
    public func newRandomBatch() {
        let hidden = Set(pending)
        randomIDs = Array(records.map(\.id).filter { !hidden.contains($0) }.shuffled().prefix(pageSize))
        mode = .random; page = 0; randomAnchor = nil
        randomGroups = [randomIDs]; randomGroupIndex = 0
    }
    /// Deterministic injection used by tests and restoration.
    public func setRandomBatch(_ ids: [String]) {
        dayIDs.removeAll(keepingCapacity: true)
        for record in self.records {
            if let date = record.date { dayIDs[calendar.startOfDay(for: date), default: []].append(record.id) }
        }
        let valid = Set(records.map(\.id)); var seen = Set<String>()
        randomIDs = Array(ids.filter { valid.contains($0) && seen.insert($0).inserted }.prefix(pageSize))
        mode = .random; page = 0
        randomGroups = [randomIDs]; randomGroupIndex = 0
    }
    @discardableResult public func toggleMode(focused id: String?) -> String? {
        switch mode {
        case .random:
            guard let id, let date = records.first(where: { $0.id == id })?.date else { return nil }
            randomAnchor = id; mode = .day(calendar.startOfDay(for: date))
            page = (allModeIDs.firstIndex(of: id) ?? 0) / pageSize
            return id
        case .day:
            mode = .random; page = 0
            return randomAnchor.flatMap { visibleIDs.contains($0) ? $0 : nil } ?? visibleIDs.first
        }
    }
    @discardableResult public func movePage(_ direction: Int) -> Bool {
        guard (direction > 0 && hasNext) || (direction < 0 && hasPrevious) else { return false }
        if case .random = mode {
            if direction < 0, let previous = previousRandomIndex {
                randomGroupIndex = previous
            } else if let next = nextRandomIndex {
                randomGroupIndex = next
            } else {
                let seen = Set(randomGroups.flatMap { $0 } + pending)
                var candidates = records.map(\.id).filter { !seen.contains($0) }
                if candidates.isEmpty {
                    let excluded = Set(randomIDs + pending)
                    candidates = records.map(\.id).filter { !excluded.contains($0) }
                }
                guard !candidates.isEmpty else { return false }
                randomGroups.append(Array(candidates.shuffled().prefix(pageSize)))
                randomGroupIndex = randomGroups.count - 1
            }
            randomIDs = randomGroups[randomGroupIndex]; randomAnchor = nil
            return true
        }
        page += direction > 0 ? 1 : -1; return true
    }
    public func stage(_ id: String) {
        guard visibleIDs.contains(id), !pending.contains(id) else { return }
        history.append(UndoEntry(id: id, mode: mode, page: page, randomIDs: randomIDs, randomGroups: randomGroups, randomGroupIndex: randomGroupIndex))
        pending.append(id); clampPage()
    }
    @discardableResult public func undo() -> String? {
        if let entry = history.popLast() {
            pending.removeAll { $0 == entry.id }; mode = entry.mode
            randomIDs = entry.randomIDs.filter { id in records.contains { $0.id == id } }
            let valid = Set(records.map(\.id))
            randomGroups = entry.randomGroups.map { $0.filter { valid.contains($0) } }
            randomGroupIndex = entry.randomGroupIndex
            page = entry.page; clampPage(); return entry.id
        }
        // Pending marks survive relaunch; recover the newest one into its day.
        guard let id = pending.popLast(), let record = records.first(where: { $0.id == id }) else { return nil }
        if let date = record.date {
            mode = .day(calendar.startOfDay(for: date)); page = (allModeIDs.firstIndex(of: id) ?? 0) / pageSize
        } else {
            mode = .random; page = 0
            randomIDs = [id] + Array(randomIDs.filter { $0 != id }.prefix(pageSize - 1))
        }
        return id
    }
    public func restore(_ id: String) {
        pending.removeAll { $0 == id }; history.removeAll { $0.id == id }; clampPage()
    }
    public func restoreAll() { pending.removeAll(); history.removeAll(); clampPage() }
    public func committed(_ ids: [String]) {
        let deleted = Set(ids)
        pending.removeAll { deleted.contains($0) }; history.removeAll { deleted.contains($0.id) }
        records.removeAll { deleted.contains($0.id) }; randomIDs.removeAll { deleted.contains($0) }
        randomGroups = randomGroups.map { $0.filter { !deleted.contains($0) } }
        for day in Array(dayIDs.keys) { dayIDs[day]?.removeAll { deleted.contains($0) } }
        clampPage()
    }
    private func clampPage() { page = max(0, min(page, max(0, (allModeIDs.count - 1) / pageSize))) }
}
