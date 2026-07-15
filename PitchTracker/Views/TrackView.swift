import SwiftUI
import CoreMedia

struct TrackView: View {
    @EnvironmentObject private var store: PitchStore
    @StateObject private var camera = CameraManager()
    @StateObject private var analyzer = TrajectoryAnalyzer()

    @State private var pitchType: PitchType = .fb
    @State private var pitchResult: PitchResult = .calledStrike
    @State private var manualVelocity: Double = 90
    @State private var pendingTap: CGPoint?
    @State private var showCalibration = false
    @State private var showNewSession = false
    @State private var pitcherName = ""

    var body: some View {
        ZStack {
            if camera.authorizationStatus == .authorized {
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            StrikeZoneOverlay(
                rect: store.strikeZoneRect,
                trajectoryPoints: analyzer.livePoints,
                pendingPoint: pendingTap,
                pitches: store.activeSession?.pitches ?? []
            )
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                statusBanner
                controlPanel
            }
        }
        .onAppear {
            camera.onSampleBuffer = { [weak analyzer] buffer in
                let ts = CMSampleBufferGetPresentationTimeStamp(buffer)
                Task { @MainActor in
                    analyzer?.process(sampleBuffer: buffer, timestamp: ts)
                }
            }
            camera.requestAccessAndStart()
            analyzer.configure(moundDistanceFt: store.moundDistanceFt, zoneRect: store.strikeZoneRect)
        }
        .onDisappear { camera.stop() }
        .onChange(of: store.moundDistanceFt) { _, v in
            analyzer.configure(moundDistanceFt: v, zoneRect: store.strikeZoneRect)
        }
        .onChange(of: store.strikeZoneRect) { _, z in
            analyzer.configure(moundDistanceFt: store.moundDistanceFt, zoneRect: z)
        }
        .onChange(of: analyzer.lastHit?.velocityMph) { _, _ in
            if let hit = analyzer.consumeLastHit() { applyHit(hit, auto: true) }
        }
        .sheet(isPresented: $showCalibration) {
            CalibrationView()
        }
        .alert("New session", isPresented: $showNewSession) {
            TextField("Pitcher name", text: $pitcherName)
            Button("Start") { store.createSession(name: pitcherName); pitcherName = "" }
            Button("Cancel", role: .cancel) {}
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    guard store.activeSession != nil else { return }
                    let nx = value.location.x / UIScreen.main.bounds.width
                    let ny = 1 - value.location.y / UIScreen.main.bounds.height
                    pendingTap = CGPoint(x: min(max(nx, 0), 1), y: min(max(ny, 0), 1))
                }
        )
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeSession?.pitcherName ?? "No session")
                    .font(.headline)
                Text("\(store.activeSession?.pitches.count ?? 0) pitches · \(Int(camera.maxFPS)) fps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { showCalibration = true } label: {
                Image(systemName: "scope")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var statusBanner: some View {
        Text(analyzer.statusText)
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.55))
            .foregroundStyle(.white)
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            if store.activeSession == nil {
                Button("Start session") { showNewSession = true }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Button("ARM") { analyzer.armTracking() }
                        .buttonStyle(.borderedProminent)
                    Button("Log manual") { logManual() }
                        .buttonStyle(.bordered)
                    Button("Undo") { store.undoLastPitch() }
                        .buttonStyle(.bordered)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(PitchType.allCases) { t in
                            Button(t.rawValue) { pitchType = t }
                                .buttonStyle(.bordered)
                                .tint(pitchType == t ? Color(hex: t.colorHex) : .gray)
                        }
                    }
                }

                HStack {
                    Text("mph")
                    Slider(value: $manualVelocity, in: 55...105, step: 1)
                    Text("\(Int(manualVelocity))")
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func applyHit(_ hit: TrajectoryHit, auto: Bool) {
        guard store.activeSession != nil else { return }
        let n = (store.activeSession?.pitches.count ?? 0) + 1
        let pitch = Pitch(
            pitchNumber: n,
            type: pitchType,
            velocity: hit.velocityMph,
            x: hit.crossingX,
            y: hit.crossingY,
            inZone: ZoneMath.inZone(hit.crossingX, hit.crossingY, rect: store.strikeZoneRect),
            result: pitchResult,
            trackedAutomatically: auto
        )
        store.addPitch(pitch)
        pendingTap = nil
        manualVelocity = hit.velocityMph
        analyzer.resetTracking()
    }

    private func logManual() {
        guard store.activeSession != nil else { return }
        let point = pendingTap ?? CGPoint(x: 0.5, y: store.strikeZoneRect.y + store.strikeZoneRect.height / 2)
        let hit = TrajectoryHit(
            crossingX: Double(point.x),
            crossingY: Double(point.y),
            velocityMph: manualVelocity,
            confidence: 1,
            points: []
        )
        applyHit(hit, auto: false)
    }
}
