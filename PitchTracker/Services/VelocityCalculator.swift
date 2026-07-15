import Foundation
import CoreGraphics

enum VelocityCalculator {
    /// Estimate mph from trajectory travel time across known distance (ft).
    static func mph(distanceFeet: Double, durationSeconds: Double, mount: CameraMount = .behindCatcher) -> Double {
        guard durationSeconds > 0.01 else { return 0 }
        let pathFeet = switch mount {
        case .behindCatcher: distanceFeet
        case .besidePitcher: distanceFeet * 1.02
        }
        let fps = pathFeet / durationSeconds
        return fps * 3600.0 / 5280.0
    }

    /// Fallback from pixel motion when scale known: feet per pixel at plate plane
    static func mphFromPixelMotion(
        deltaNormalized: CGFloat,
        frameSize: CGSize,
        plateDistanceFt: Double,
        frameDuration: Double,
        pixelsPerFootAtPlate: Double = 18
    ) -> Double {
        let pixelDelta = deltaNormalized * frameSize.width
        let feet = Double(pixelDelta) / pixelsPerFootAtPlate
        return mph(distanceFeet: feet, durationSeconds: frameDuration)
    }
}

struct TrajectoryHit {
    var crossingX: Double
    var crossingY: Double
    var velocityMph: Double
    var confidence: Double
    var points: [CGPoint]
}
