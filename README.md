# Pitch Tracker — Native iOS (IPA / AltStore)

Camera-based **velocity** and **strike zone** tracker for bullpen and live pitching sessions.

## Features

- **Live camera** with strike zone overlay (calibrate to real zone)
- **Apple Vision** ball trajectory detection (`VNDetectTrajectoriesRequest`)
- **Velocity estimate** from flight time + mound distance (calibrated)
- **Manual fallback** — tap location + mph if auto-track misses
- **Sessions** — stats, pitch log, JSON export
- **120 fps** capture when device supports it

## Requirements

- Mac with **full Xcode** (App Store)
- iPhone iOS **17+**
- [AltStore](https://altstore.io) on your iPhone (or Apple Developer account)

## Build IPA for AltStore

1. Open Xcode once and sign in with your Apple ID (**Settings → Accounts**).

2. Open the project:
   ```bash
   open /Users/henryblaney/Desktop/VIP/pitch-tracker-ios/PitchTracker.xcodeproj
   ```

3. Select the **PitchTracker** target → **Signing & Capabilities** → choose your **Team** (Personal Team is fine for AltStore).

4. **Archive & export:**
   ```bash
   cd /Users/henryblaney/Desktop/VIP/pitch-tracker-ios
   chmod +x scripts/build_ipa.sh
   DEVELOPMENT_TEAM=YOUR_TEAM_ID ./scripts/build_ipa.sh
   ```
   Or in Xcode: **Product → Archive → Distribute App → Development → Export**.

5. **AltStore:** AirDrop/copy the `.ipa` to your iPhone → open in AltStore → Install.

   AltStore refreshes every 7 days with a free Apple ID.

## How to use (camera tracking)

1. **Start session** → enter pitcher name  
2. **Calibrate** (scope icon) → align green box with strike zone; set mound distance (60.5 ft MLB, ~46 ft bullpen)  
3. Mount phone **behind catcher**, keep it **still**  
4. Tap **ARM** as the pitcher releases  
5. Vision tracks the ball path → logs **mph + zone location**  
6. If auto-track fails → **tap** where it crossed + **Log manual**

## Accuracy notes (important)

| Method | Expectation |
|--------|-------------|
| Radar gun / Rapsodo | ±0.1 mph — gold standard |
| **This app (camera)** | Rough estimate ±3–8 mph depending on lighting, FPS, distance |
| Manual tap + typed mph | As good as your radar reading |

Camera tracking works best when:
- Tripod / stable mount  
- High contrast ball  
- Bullpen distance with slow-mo/high FPS  
- You calibrate mound distance correctly  

It is **not** TrackMan/Rapsodo replacement — it's a portable tool that gets you zone + trend data in the field.

## Project structure

```
pitch-tracker-ios/
  PitchTracker.xcodeproj   ← open in Xcode
  PitchTracker/
    Services/CameraManager.swift      AVFoundation high-FPS capture
    Services/TrajectoryAnalyzer.swift Vision trajectory + zone crossing
    Views/TrackView.swift             Main camera UI
  scripts/build_ipa.sh                Command-line IPA export
```

## Regenerate Xcode project

If you edit `project.yml`:

```bash
/tmp/xcodegen/xcodegen/bin/xcodegen generate
```

(Download XcodeGen once — see `scripts/build_ipa.sh`.)

## Roadmap

- [ ] Bluetooth Pocket Radar / Stalker import  
- [ ] Heat map density view  
- [ ] Clip export per pitch  
- [ ] Apple Watch remote ARM trigger  
