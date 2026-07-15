import SwiftUI
import CoreMedia

struct TrackView: View {
    @EnvironmentObject private var store: PitchStore
    @StateObject private var camera = CameraManager()
    @StateObject private var analyzer = TrajectoryAnalyzer()

    @State private var lastPitchFlash: PitchFlash?

    var body: some View {
        ZStack {
            if camera.authorizationStatus == .authorized {
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            StrikeZoneOverlay(
                mount: store.cameraMount,
                rect: store.strikeZoneRect,
                trajectoryPoints: analyzer.livePoints,
                pendingPoint: nil,
                pitches: store.activeSession?.pitches ?? []
            )
            .ignoresSafeArea()

            VStack {
                passiveHUD
                Spacer()
                if let flash = lastPitchFlash {
                    pitchFlashBanner(flash)
                        .transition(.opacity)
                }
            }

            if camera.authorizationStatus != .authorized {
                Text("Allow camera access to track pitches automatically.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .keepScreenAwake()
        .onAppear {
            store.ensureActiveSession()
            camera.onSampleBuffer = { [weak analyzer] buffer in
                let ts = CMSampleBufferGetPresentationTimeStamp(buffer)
                Task { @MainActor in
                    analyzer?.process(sampleBuffer: buffer, timestamp: ts)
                }
            }
            camera.requestAccessAndStart()
            syncAnalyzer()
            analyzer.startListening()
        }
        .onDisappear {
            camera.stop()
            analyzer.resetTracking()
        }
        .onChange(of: store.moundDistanceFt) { _, _ in
            syncAnalyzer()
            analyzer.startListening()
        }
        .onChange(of: store.strikeZoneRect) { _, _ in
            syncAnalyzer()
            analyzer.startListening()
        }
        .onChange(of: store.cameraMount) { _, _ in
            syncAnalyzer()
            analyzer.startListening()
        }
        .onChange(of: analyzer.lastHit?.velocityMph) { _, _ in
            if let hit = analyzer.consumeLastHit() { applyHit(hit) }
        }
    }

    private var passiveHUD: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.activeSession?.pitcherName ?? "Bullpen")
                    .font(.headline)
                Text("\(store.activeSession?.pitches.count ?? 0) pitches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let session = store.activeSession, !session.pitches.isEmpty {
                    Text("Avg \(session.stats.avgVelo) · Max \(session.stats.maxVelo) mph")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("AUTO")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                Text("\(Int(camera.maxFPS)) fps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(store.cameraMount == .besidePitcher ? "BESIDE" : "BEHIND")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.85))
    }

    private func syncAnalyzer() {
        analyzer.configure(
            moundDistanceFt: store.moundDistanceFt,
            zoneRect: store.strikeZoneRect,
            mount: store.cameraMount
        )
    }

    private func pitchFlashBanner(_ flash: PitchFlash) -> some View {
        VStack(spacing: 4) {
            Text("\(flash.velocity) mph")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text(flash.label)
                .font(.title3.bold())
                .foregroundStyle(flash.inZone ? .green : .orange)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.65))
    }

    private func applyHit(_ hit: TrajectoryHit) {
        guard store.activeSession != nil else { return }
        let inZone = ZoneMath.inZone(hit.crossingX, hit.crossingY, rect: store.strikeZoneRect)
        let n = (store.activeSession?.pitches.count ?? 0) + 1
        let pitch = Pitch(
            pitchNumber: n,
            type: .fb,
            velocity: hit.velocityMph,
            x: hit.crossingX,
            y: hit.crossingY,
            inZone: inZone,
            result: inZone ? .calledStrike : .ball,
            trackedAutomatically: true
        )
        store.addPitch(pitch)

        let flash = PitchFlash(
            velocity: Int(hit.velocityMph.rounded()),
            inZone: inZone,
            label: inZone ? "STRIKE" : "BALL"
        )
        withAnimation { lastPitchFlash = flash }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            await MainActor.run {
                withAnimation {
                    if lastPitchFlash == flash { lastPitchFlash = nil }
                }
            }
        }

        analyzer.prepareForNextPitch()
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                if analyzer.isTracking {
                    analyzer.statusText = "Listening — just pitch"
                }
            }
        }
    }
}

private struct PitchFlash: Equatable {
    let velocity: Int
    let inZone: Bool
    let label: String
}

private extension View {
    func keepScreenAwake() -> some View {
        onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
