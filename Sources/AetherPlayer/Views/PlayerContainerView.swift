import SwiftUI
import AetherEngine

struct PlayerContainerView: View {
    let model: PlayerViewModel
    var body: some View {
        AetherPlayerSurface(engine: model.engine)
            .onTapGesture { model.togglePlayPause() }
    }
}
