import SwiftUI

/// Full-screen tap catcher below the controls, above the video. Single tap toggles the chrome;
/// double-tap left/right third skips -/+10s, center toggles play/pause. A plain Color.clear layer
/// reliably receives empty-area taps; the controls render above and win their own hits.
struct PlayerGestureCatcher: View {
    let onToggleControls: () -> Void
    let onSkip: (Double) -> Void
    let onTogglePlayPause: () -> Void
    private let skipInterval: Double = 10

    var body: some View {
        GeometryReader { geo in
            Color.clear.contentShape(Rectangle())
                .onTapGesture(count: 2, coordinateSpace: .local) { location in
                    if let seconds = PlayerTouchInput.skipSeconds(forTapX: location.x, width: geo.size.width, interval: skipInterval) {
                        onSkip(seconds)
                    } else {
                        onTogglePlayPause()
                    }
                }
                .onTapGesture { onToggleControls() }
        }
    }
}
