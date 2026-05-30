import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AetherEngine

struct ContentView: View {
    @State private var model: PlayerViewModel
    @State private var isDropTargeted = false

    init(model: PlayerViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if model.hasMedia {
                PlayerContainerView(model: model)
                    .ignoresSafeArea()
            } else {
                EmptyStateView(isDropTargeted: isDropTargeted, onOpen: openPanel)
            }

            if let err = model.loadError {
                VStack {
                    Spacer()
                    Text(err)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 24)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in await model.open(url: url) }
            }
            return true
        }
        .onChange(of: model.loadedURL) { _, url in
            NSApp.keyWindow?.title = url?.lastPathComponent ?? "AetherPlayer"
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie]
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.open(url: url) }
        }
    }
}
