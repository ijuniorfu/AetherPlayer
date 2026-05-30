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
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.loadError)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    // A subtitle file dropped onto a playing video attaches as
                    // a sidecar track; anything else loads as a new video.
                    if Self.subtitleExtensions.contains(url.pathExtension.lowercased()), model.hasMedia {
                        model.loadSidecarSubtitle(url: url)
                    } else {
                        await model.open(url: url)
                    }
                }
            }
            return true
        }
        .onChange(of: model.loadedURL) { _, url in
            NSApp.keyWindow?.title = url?.lastPathComponent ?? "AetherPlayer"
        }
        .onChange(of: model.loadError) { _, err in
            // Auto-dismiss the error toast after a few seconds, unless a newer
            // error replaced it in the meantime.
            guard err != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                if model.loadError == err { model.clearLoadError() }
            }
        }
    }

    /// Sidecar subtitle file extensions recognized on drop.
    private static let subtitleExtensions: Set<String> = ["srt", "ass", "ssa", "vtt", "sub"]

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
