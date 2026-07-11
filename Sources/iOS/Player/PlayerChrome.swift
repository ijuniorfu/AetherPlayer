import SwiftUI

struct PlayerChrome: View {
    let model: PlayerViewModel
    @State private var controlsVisible = true
    @State private var lastActivity = Date()
    @State private var scrubbing = false
    @State private var showTracks = false

    private let hideInterval: TimeInterval = 3.5

    var body: some View {
        ZStack {
            PlayerGestureCatcher(
                onToggleControls: { toggleControls() },
                onSkip: { model.seek(by: $0); bumpActivity() },
                onTogglePlayPause: { model.togglePlayPause(); bumpActivity() }
            )
            if controlsVisible {
                VStack {
                    PlayerTopBar(model: model, onTracks: { showTracks = true; bumpActivity() })
                    Spacer()
                    PlayerTransportBar(model: model, scrubbing: $scrubbing)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showTracks) { TracksSheet(model: model) }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard controlsVisible else { return }          // hidden: leave hidden
            if scrubbing || showTracks {                   // keep up while scrubbing / sheet open
                lastActivity = Date(); return
            }
            if shouldHideControls(now: Date().timeIntervalSinceReferenceDate,
                                  lastActivity: lastActivity.timeIntervalSinceReferenceDate,
                                  interval: hideInterval) {
                withAnimation { controlsVisible = false }
            }
        }
    }

    /// Single tap: toggle. Hiding must NOT go through bumpActivity (which forces visible).
    private func toggleControls() {
        if controlsVisible {
            withAnimation { controlsVisible = false }
        } else {
            lastActivity = Date()
            withAnimation { controlsVisible = true }
        }
    }
    /// A user action (skip / play / open tracks): reset the timer and ensure controls are up.
    private func bumpActivity() {
        lastActivity = Date()
        if !controlsVisible { withAnimation { controlsVisible = true } }
    }
}
