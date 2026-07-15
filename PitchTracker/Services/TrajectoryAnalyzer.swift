import Vision
import CoreMedia
import CoreGraphics

@MainActor
final class TrajectoryAnalyzer: ObservableObject {
    @Published var livePoints: [CGPoint] = []
    @Published var lastHit: TrajectoryHit?
    @Published var isTracking = false
    @Published var statusText = "Listening — just pitch"

    private var request: VNDetectTrajectoriesRequest?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var idleFrames = 0
    private var firstTimestamp: CMTime?
    private var lastTimestamp: CMTime?
    private var moundDistanceFt: Double = 60.5
    private var zoneRect: StrikeZoneRect = .default
    private let idleReset = 18
    private var cooldownUntil: Date?

    private var frameCount = 0
    private var lastFrameTime: CMTime?

    func configure(moundDistanceFt: Double, zoneRect: StrikeZoneRect) {
        self.moundDistanceFt = moundDistanceFt
        self.zoneRect = zoneRect
        prepareForNextPitch()
        setupRequest()
    }

    /// Always-on mode — no button press before each pitch.
    func startListening() {
        isTracking = true
        cooldownUntil = nil
        statusText = "Listening — just pitch"
    }

    func prepareForNextPitch() {
        livePoints = []
        lastHit = nil
        idleFrames = 0
        frameCount = 0
        firstTimestamp = nil
        lastTimestamp = nil
        lastFrameTime = nil
        sequenceHandler = VNSequenceRequestHandler()
        setupRequest()
    }

    func resetTracking() {
        prepareForNextPitch()
        isTracking = false
        statusText = "Paused"
    }

    private func setupRequest() {
        request = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 8) { [weak self] req, err in
            Task { @MainActor in
                self?.handleResults(req: req, error: err)
            }
        }
        request?.regionOfInterest = CGRect(x: 0, y: 0.15, width: 1, height: 0.75)
        request?.objectMinimumNormalizedRadius = 0.004
        request?.objectMaximumNormalizedRadius = 0.06
    }

    func process(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        guard isTracking, let request else { return }
        if let cooldownUntil, Date() < cooldownUntil { return }
        lastFrameTime = timestamp
        frameCount += 1
        do {
            try sequenceHandler.perform([request], on: sampleBuffer)
        } catch {
            statusText = "Vision: \(error.localizedDescription)"
        }
    }

    private func handleResults(req: VNRequest, error: Error?) {
        guard isTracking else { return }
        if let error {
            statusText = error.localizedDescription
            return
        }
        guard let observations = req.results as? [VNTrajectoryObservation], !observations.isEmpty else {
            idleFrames += 1
            if idleFrames > idleReset, !livePoints.isEmpty {
                finalizeIfNeeded()
            }
            return
        }

        idleFrames = 0
        guard let obs = observations.max(by: { $0.detectedPoints.count < $1.detectedPoints.count }) else { return }

        let points = obs.detectedPoints.map { CGPoint(x: CGFloat($0.x), y: 1 - CGFloat($0.y)) }
        livePoints = points

        if firstTimestamp == nil { firstTimestamp = lastFrameTime }
        if let lastFrameTime { lastTimestamp = lastFrameTime }

        if obs.confidence > 0.3, points.count >= 6 {
            _ = obs.uuid
        }
    }

    private func finalizeIfNeeded() {
        guard let first = firstTimestamp, let last = lastTimestamp, !livePoints.isEmpty else {
            resetIdleOnly()
            return
        }
        let duration = CMTimeGetSeconds(CMTimeSubtract(last, first))
        guard duration > 0.05 else { resetIdleOnly(); return }

        guard let crossing = plateCrossingPoint(from: livePoints) else {
            resetIdleOnly()
            return
        }

        let mph = VelocityCalculator.mph(distanceFeet: moundDistanceFt, durationSeconds: duration)
        let clamped = zoneRect.clampPoint(crossing.x, crossing.y)
        let hit = TrajectoryHit(
            crossingX: clamped.0,
            crossingY: clamped.1,
            velocityMph: mph.clamped(to: 45...105),
            confidence: 0.7,
            points: livePoints
        )
        lastHit = hit
        cooldownUntil = Date().addingTimeInterval(2.0)
        statusText = String(format: "Logged %.0f mph — listening", hit.velocityMph)
        resetIdleOnly()
    }

    func consumeLastHit() -> TrajectoryHit? {
        defer { lastHit = nil }
        return lastHit
    }

    private func resetIdleOnly() {
        livePoints = []
        idleFrames = 0
        firstTimestamp = nil
        lastTimestamp = nil
    }

    /// Intersect trajectory polyline with bottom edge of strike zone overlay (plate plane proxy).
    private func plateCrossingPoint(from points: [CGPoint]) -> (x: Double, y: Double)? {
        let plateY = zoneRect.y + zoneRect.height
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            if (a.y <= plateY && b.y >= plateY) || (a.y >= plateY && b.y <= plateY) {
                let t = abs(plateY - a.y) / max(abs(b.y - a.y), 0.0001)
                let x = Double(a.x + (b.x - a.x) * t)
                return (x, Double(plateY))
            }
        }
        return points.last.map { (Double($0.x), Double($0.y)) }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
