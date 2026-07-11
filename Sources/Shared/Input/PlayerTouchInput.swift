import CoreGraphics

/// Pure gesture-to-intent mapper for the iOS touch player, shared by the SwiftUI gesture catcher
/// and unit tests. Left third seeks back, right third seeks forward, middle is play/pause.
enum PlayerTouchInput {
    static func skipSeconds(forTapX x: CGFloat, width: CGFloat, interval: Double) -> Double? {
        guard width > 0 else { return nil }
        if x < width / 3 { return -interval }
        if x > width * 2 / 3 { return interval }
        return nil
    }
}
