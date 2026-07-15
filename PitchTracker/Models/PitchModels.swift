import Foundation
import CoreGraphics

enum PitchType: String, Codable, CaseIterable, Identifiable {
    case fb = "FB", sl = "SL", cb = "CB", ch = "CH", ct = "CT", sp = "SP", other = "OTHER"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .fb: return "Fastball"
        case .sl: return "Slider"
        case .cb: return "Curve"
        case .ch: return "Change"
        case .ct: return "Cutter"
        case .sp: return "Splitter"
        case .other: return "Other"
        }
    }

    var colorHex: UInt {
        switch self {
        case .fb: return 0xEF4444
        case .sl: return 0x3B82F6
        case .cb: return 0xA855F7
        case .ch: return 0x22C55E
        case .ct: return 0xF97316
        case .sp: return 0x14B8A6
        case .other: return 0x94A3B8
        }
    }
}

enum PitchResult: String, Codable, CaseIterable, Identifiable {
    case calledStrike, swingingStrike, foul, ball, inPlay
    var id: String { rawValue }

    var label: String {
        switch self {
        case .calledStrike: return "Called K"
        case .swingingStrike: return "Whiff"
        case .foul: return "Foul"
        case .ball: return "Ball"
        case .inPlay: return "In play"
        }
    }
}

struct Pitch: Identifiable, Codable, Equatable {
    var id: UUID
    var pitchNumber: Int
    var type: PitchType
    var velocity: Double
    /// Normalized strike-zone plane 0...1 (catcher view)
    var x: Double
    var y: Double
    var inZone: Bool
    var result: PitchResult
    var timestamp: Date
    var trackedAutomatically: Bool

    init(
        id: UUID = UUID(),
        pitchNumber: Int,
        type: PitchType,
        velocity: Double,
        x: Double,
        y: Double,
        inZone: Bool,
        result: PitchResult,
        timestamp: Date = Date(),
        trackedAutomatically: Bool = false
    ) {
        self.id = id
        self.pitchNumber = pitchNumber
        self.type = type
        self.velocity = velocity
        self.x = x
        self.y = y
        self.inZone = inZone
        self.result = result
        self.timestamp = timestamp
        self.trackedAutomatically = trackedAutomatically
    }
}

struct PitchSession: Identifiable, Codable, Equatable {
    var id: UUID
    var pitcherName: String
    var createdAt: Date
    var pitches: [Pitch]
    var moundDistanceFt: Double

    init(id: UUID = UUID(), pitcherName: String, createdAt: Date = Date(), pitches: [Pitch] = [], moundDistanceFt: Double = 60.5) {
        self.id = id
        self.pitcherName = pitcherName
        self.createdAt = createdAt
        self.pitches = pitches
        self.moundDistanceFt = moundDistanceFt
    }

    var stats: SessionStats { SessionStats(pitches: pitches) }
}

struct SessionStats {
    let count: Int
    let avgVelo: Int
    let maxVelo: Int
    let zonePct: Int
    let strikePct: Int

    init(pitches: [Pitch]) {
        count = pitches.count
        guard !pitches.isEmpty else {
            avgVelo = 0; maxVelo = 0; zonePct = 0; strikePct = 0
            return
        }
        let velos = pitches.map(\.velocity)
        avgVelo = Int((velos.reduce(0, +) / Double(velos.count)).rounded())
        maxVelo = Int(velos.max() ?? 0)
        zonePct = Int((Double(pitches.filter(\.inZone).count) / Double(pitches.count) * 100).rounded())
        let strikes = pitches.filter { $0.result != .ball }.count
        strikePct = Int((Double(strikes) / Double(pitches.count) * 100).rounded())
    }
}

struct StrikeZoneRect: Codable, Equatable {
    /// Normalized overlay rect on camera preview (0-1)
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let `default` = StrikeZoneRect(x: 0.34, y: 0.28, width: 0.32, height: 0.36)

    func contains(normalized nx: Double, ny: Double) -> Bool {
        nx >= x && nx <= x + width && ny >= y && ny <= y + height
    }

    func clampPoint(_ nx: Double, _ ny: Double) -> (Double, Double) {
        (min(max(nx, 0), 1), min(max(ny, 0), 1))
    }
}

enum ZoneMath {
    static func inZone(_ nx: Double, _ ny: Double, rect: StrikeZoneRect) -> Bool {
        rect.contains(normalized: nx, ny: ny)
    }
}
