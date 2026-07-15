import Foundation

@MainActor
final class PitchStore: ObservableObject {
    @Published private(set) var sessions: [PitchSession] = []
    @Published var activeSessionID: UUID?
    @Published var strikeZoneRect: StrikeZoneRect = .default
    @Published var moundDistanceFt: Double = 60.5

    private let storageKey = "pitch-tracker-ios-sessions-v1"
    private let zoneKey = "pitch-tracker-zone-v1"
    private let moundKey = "pitch-tracker-mound-ft"
    private let pitcherKey = "pitch-tracker-last-pitcher"

    init() {
        load()
    }

    var lastPitcherName: String {
        UserDefaults.standard.string(forKey: pitcherKey) ?? "Bullpen"
    }

    /// Hands-free: resume or create a session without prompts.
    func ensureActiveSession() {
        if activeSession != nil { return }
        if let latest = sessions.first {
            activeSessionID = latest.id
            return
        }
        createSession(name: lastPitcherName)
    }

    var activeSession: PitchSession? {
        guard let id = activeSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    func createSession(name: String) {
        let resolved = name.isEmpty ? "Bullpen" : name
        let session = PitchSession(pitcherName: resolved, moundDistanceFt: moundDistanceFt)
        sessions.insert(session, at: 0)
        activeSessionID = session.id
        UserDefaults.standard.set(resolved, forKey: pitcherKey)
        persist()
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if activeSessionID == id { activeSessionID = sessions.first?.id }
        persist()
    }

    func addPitch(_ pitch: Pitch) {
        guard let idx = sessions.firstIndex(where: { $0.id == activeSessionID }) else { return }
        sessions[idx].pitches.append(pitch)
        persist()
    }

    func undoLastPitch() {
        guard let idx = sessions.firstIndex(where: { $0.id == activeSessionID }) else { return }
        guard !sessions[idx].pitches.isEmpty else { return }
        sessions[idx].pitches.removeLast()
        persist()
    }

    func updateZone(_ rect: StrikeZoneRect) {
        strikeZoneRect = rect
        UserDefaults.standard.set(try? JSONEncoder().encode(rect), forKey: zoneKey)
    }

    func updateMoundDistance(_ ft: Double) {
        moundDistanceFt = ft
        UserDefaults.standard.set(ft, forKey: moundKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([PitchSession].self, from: data) {
            sessions = decoded
            activeSessionID = decoded.first?.id
        }
        if let zdata = UserDefaults.standard.data(forKey: zoneKey),
           let zone = try? JSONDecoder().decode(StrikeZoneRect.self, from: zdata),
           zone.isPlausible {
            strikeZoneRect = zone
        }
        let mound = UserDefaults.standard.double(forKey: moundKey)
        if mound > 0 { moundDistanceFt = mound }
    }

    func exportActiveSessionJSON() -> URL? {
        guard let session = activeSession,
              let data = try? JSONEncoder().encode(session) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(session.pitcherName.replacingOccurrences(of: " ", with: "-"))-\(session.createdAt.formatted(date: .numeric, time: .omitted)).json")
        try? data.write(to: url)
        return url
    }
}
