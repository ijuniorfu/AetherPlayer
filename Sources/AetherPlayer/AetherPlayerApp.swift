import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct AetherPlayerApp: App {
    @State private var model: PlayerViewModel? = {
        try? PlayerViewModel()
    }()

    var body: some Scene {
        Window("AetherPlayer", id: "main") {
            Group {
                if let model {
                    ContentView(model: model)
                } else {
                    Text("AetherEngine failed to initialize.")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                }
            }
            .frame(minWidth: 640, minHeight: 360)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open\u{2026}") { openFile() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    private func openFile() {
        guard let model else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video]
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.open(url: url) }
        }
    }
}
