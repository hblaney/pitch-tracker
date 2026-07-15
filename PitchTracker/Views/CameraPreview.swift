import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let camera: CameraManager

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer = camera.makePreviewLayer()
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer?.session = camera.session
    }
}

final class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            guard let previewLayer else { return }
            previewLayer.frame = bounds
            layer.insertSublayer(previewLayer, at: 0)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

struct StrikeZoneOverlay: View {
    let mount: CameraMount
    let rect: StrikeZoneRect
    let trajectoryPoints: [CGPoint]
    let pendingPoint: CGPoint?
    let pitches: [Pitch]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let zoneRect = CGRect(
                x: rect.x * w,
                y: (1 - rect.y - rect.height) * h,
                width: rect.width * w,
                height: rect.height * h
            )
            ZStack {
                if mount == .behindCatcher {
                    StrikeZonePlateShape()
                        .stroke(Color.green.opacity(0.95), lineWidth: 2)
                        .background(
                            StrikeZonePlateShape()
                                .fill(Color.green.opacity(0.08))
                        )
                        .frame(width: zoneRect.width, height: zoneRect.height + zoneRect.width * 0.42)
                        .position(
                            x: zoneRect.midX,
                            y: zoneRect.midY + zoneRect.width * 0.21
                        )
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.green.opacity(0.95), lineWidth: 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.08)))
                        .frame(width: zoneRect.width, height: zoneRect.height)
                        .position(x: zoneRect.midX, y: zoneRect.midY)
                }

                Path { path in
                    guard trajectoryPoints.count > 1 else { return }
                    path.move(to: CGPoint(x: trajectoryPoints[0].x * w, y: (1 - trajectoryPoints[0].y) * h))
                    for p in trajectoryPoints.dropFirst() {
                        path.addLine(to: CGPoint(x: p.x * w, y: (1 - p.y) * h))
                    }
                }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 3]))

                ForEach(pitches.suffix(20)) { pitch in
                    Circle()
                        .fill(Color(hex: pitch.type.colorHex))
                        .frame(width: 10, height: 10)
                        .position(x: pitch.x * w, y: (1 - pitch.y) * h)
                }

                if let pendingPoint {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .position(x: pendingPoint.x * w, y: (1 - pendingPoint.y) * h)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Strike zone rectangle with home plate attached at the bottom (catcher view).
struct StrikeZonePlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        let zoneHeight = rect.height / 1.42
        let plateHeight = rect.height - zoneHeight
        let zone = CGRect(x: 0, y: 0, width: rect.width, height: zoneHeight)

        var path = Path()
        path.addRect(zone)

        let inset = rect.width * 0.12
        let plateTop = zoneHeight
        path.move(to: CGPoint(x: inset, y: plateTop))
        path.addLine(to: CGPoint(x: rect.width - inset, y: plateTop))
        path.addLine(to: CGPoint(x: rect.width, y: plateTop + plateHeight * 0.45))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: plateTop + plateHeight * 0.45))
        path.closeSubpath()

        return path
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
