import SwiftUI
import AVKit

struct RootView: View {
    @Bindable var model: PlayerViewModel
    @State private var showTracks = false

    var body: some View {
        HomeView(model: model)
            .fullScreenCover(isPresented: Binding(
                get: { model.hasMedia },
                set: { if !$0 { model.stop() } })) {
                ZStack(alignment: .topTrailing) {
                    PlayerPresenter(model: model).ignoresSafeArea()
                    Button {
                        showTracks = true
                    } label: {
                        Image(systemName: "list.bullet").padding(12)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    .padding()
                }
                .sheet(isPresented: $showTracks) {
                    TracksSheet(model: model)
                }
            }
    }
}
