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
                PlayerPresenter(model: model)
                    .ignoresSafeArea()
                    .overlay(alignment: .topLeading) {
                        Button {
                            model.stop()
                        } label: {
                            Image(systemName: "xmark").padding(12)
                        }
                        .background(.ultraThinMaterial, in: Circle())
                        .padding()
                    }
                    .overlay(alignment: .topTrailing) {
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
