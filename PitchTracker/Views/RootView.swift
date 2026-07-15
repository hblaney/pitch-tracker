import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject private var store: PitchStore
    @Environment(\.dismiss) private var dismiss

    @State private var rect: StrikeZoneRect
    @State private var mound: Double

    init() {
        _rect = State(initialValue: .default)
        _mound = State(initialValue: 60.5)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Setup") {
                    Text("Mount phone behind catcher or on a tripod. Align the green box with the real strike zone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Stepper("Mound distance: \(mound, specifier: "%.1f") ft", value: $mound, in: 40...66, step: 0.5)
                }
                Section("Strike zone overlay") {
                    Text("Green box = rulebook zone (17\" wide). Align it with the real zone behind the plate.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Left") { Slider(value: $rect.x, in: 0.1...0.55) }
                    LabeledContent("Bottom") { Slider(value: $rect.y, in: 0.15...0.55) }
                    LabeledContent("Width") { Slider(value: $rect.width, in: 0.18...0.42) }
                    Button("Reset zone to default") {
                        rect = .default
                    }
                }
                .onChange(of: rect.width) { _, _ in
                    rect = rect.withCorrectAspect()
                }
                Section("Tips for camera tracking") {
                    Label("Mount phone and forget it — pitches log automatically", systemImage: "hands.sparkles")
                    Label("Stable scene — camera must not move during pitch", systemImage: "camera.fill")
                    Label("Bright ball / dark background works best", systemImage: "sun.max")
                    Label("Works best bullpen 40–60 ft; MLB mound 60.5 ft", systemImage: "ruler")
                }
            }
            .navigationTitle("Calibrate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateZone(rect)
                        store.updateMoundDistance(mound)
                        dismiss()
                    }
                }
            }
            .onAppear {
                rect = store.strikeZoneRect
                mound = store.moundDistanceFt
            }
        }
    }
}

struct SessionsView: View {
    @EnvironmentObject private var store: PitchStore
    @State private var shareURL: URL?
    @State private var showCalibration = false
    @State private var showNewSession = false
    @State private var pitcherName = ""

    var body: some View {
        NavigationStack {
            List {
                if let session = store.activeSession {
                    Section("Live stats") {
                        StatRow(label: "Avg mph", value: "\(session.stats.avgVelo)")
                        StatRow(label: "Max mph", value: "\(session.stats.maxVelo)")
                        StatRow(label: "In zone", value: "\(session.stats.zonePct)%")
                        StatRow(label: "Strikes", value: "\(session.stats.strikePct)%")
                    }
                    Section("Recent pitches") {
                        ForEach(session.pitches.suffix(10).reversed()) { p in
                            HStack {
                                Text("#\(p.pitchNumber)")
                                Text(p.type.rawValue).bold()
                                Spacer()
                                Text("\(Int(p.velocity)) mph")
                                Text(p.inZone ? "Z" : "C").foregroundStyle(p.inZone ? .green : .orange)
                                if p.trackedAutomatically { Image(systemName: "camera.viewfinder").font(.caption2) }
                            }
                        }
                        if !session.pitches.isEmpty {
                            Button("Undo last pitch") { store.undoLastPitch() }
                        }
                    }
                }
                Section("Sessions") {
                    ForEach(store.sessions) { s in
                        Button {
                            store.activeSessionID = s.id
                        } label: {
                            HStack {
                                Text(s.pitcherName)
                                Spacer()
                                Text("\(s.pitches.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx {
                            store.deleteSession(store.sessions[i].id)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Calibrate") { showCalibration = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button("New") { showNewSession = true }
                        if let url = store.exportActiveSessionJSON() {
                            ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCalibration) {
                CalibrationView()
            }
            .alert("New session", isPresented: $showNewSession) {
                TextField("Pitcher name", text: $pitcherName)
                Button("Start") {
                    store.createSession(name: pitcherName)
                    pitcherName = ""
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack { Text(label); Spacer(); Text(value).bold() }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TrackView()
                .tabItem { Label("Track", systemImage: "camera.viewfinder") }
            SessionsView()
                .tabItem { Label("Sessions", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
