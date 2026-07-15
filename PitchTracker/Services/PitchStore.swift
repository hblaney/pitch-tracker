import Foundation

@MainActor
final class PitchStore: ObservableObject {
    @Published private(set) var sessions: [PitchSession] = []
    @Published var activeSessionID: UUID?
    @Published var strikeZoneRect: StrikeZoneRect = .defaultZone(for: .besidePitcher, handedness: .right)
    @Published var moundDistanceFt: Double = 46
    @Published var cameraMount: CameraMount = .besidePitcher
    @Published var pitcherHandedness: PitcherHandedness = .right

    private let storageKey = "pitch-tracker-ios-sessions-v1"
    private let zoneKey = "pitch-tracker-zone-v2"
    private let moundKey = "pitch-tracker-mound-ft"
    private let pitcherKey = "pitch-tracker-last-pitcher"
    private let mountKey = "pitch-tracker-camera-mount"
    private let handednessKey = "pitch-tracker-handedness"

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

    func updateCameraSetup(mount: CameraMount, handedness: PitcherHandedness, resetZone: Bool) {
        cameraMount = mount
        pitcherHandedness = handedness
        UserDefaults.standard.set(mount.rawValue, forKey: mountKey)
        UserDefaults.standard.set(handedness.rawValue, forKey: handednessKey)
        if resetZone {
            strikeZoneRect = StrikeZoneRect.defaultZone(for: mount, handedness: handedness)
            UserDefaults.standard.set(try? JSONEncoder().encode(strikeZoneRect), forKey: zoneKey)
        }
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
        if let rawMount = UserDefaults.standard.string(forKey: mountKey),
           let mount = CameraMount(rawValue: rawMount) {
            cameraMount = mount
        }
        if let rawHand = UserDefaults.standard.string(forKey: handednessKey),
           let hand = PitcherHandedness(rawValue: rawHand) {
            pitcherHandedness = hand
        }
        let mound = UserDefaults.standard.double(forKey: moundKey)
        if mound > 0 {
            moundDistanceFt = mound
        } else if cameraMount == .besidePitcher {
            moundDistanceFt = 46
        }
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
