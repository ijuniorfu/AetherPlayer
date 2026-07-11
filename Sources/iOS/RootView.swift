import SwiftUI
import AVKit

struct RootView: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        HomeView(model: model)
            .fullScreenCover(isPresented: Binding(
                get: { model.hasMedia },
                set: { if !$0 { model.stop() } })) {
                // Temporary bare presentation, replaced by PlayerPresenter in Phase 2.
                TemporaryPlayerView(model: model)
            }
    }
}

private struct TemporaryPlayerView: View {
    let model: PlayerViewModel
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text(model.loadedURL?.lastPathComponent ?? "Playing")
                    .foregroundStyle(.white)
                Button("Close") { model.stop() }.foregroundStyle(.white)
            }
        }
    }
}
