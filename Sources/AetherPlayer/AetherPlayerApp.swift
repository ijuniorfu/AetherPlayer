import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct AetherPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var model: PlayerViewModel? = {
        try? PlayerViewModel()
    }()
    @State private var alwaysOnTop = false
#if DIRECT_DISTRIBUTION
    @StateObject private var updater = Updater()
#endif

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
            .onAppear {
                NSApp.windows.first?.setFrameAutosaveName("AetherPlayerMainWindow")
                if let model {
                    // Activation/fronting is handled in AppDelegate; just load.
                    AppDelegate.onOpenFiles = { urls in
                        guard let url = urls.first else { return }
                        Task { @MainActor in await model.open(url: url) }
                    }
                }
            }
            .onChange(of: alwaysOnTop) { _, on in
                NSApp.keyWindow?.level = on ? .floating : .normal
            }
            .frame(minWidth: 640, minHeight: 360)
        }
        .windowResizability(.contentMinSize)
        .commands {
#if DIRECT_DISTRIBUTION
            CommandGroup(after: .appInfo) {
                Button("Check for Updates\u{2026}") { updater.checkForUpdates() }
            }
#endif
            CommandGroup(replacing: .newItem) {
                Button("Open\u{2026}") { openFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Open Folder\u{2026}") { openFolderPanel() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Frame As\u{2026}") {
                    if let model { SnapshotSaver.captureAndSave(model: model) }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(model?.hasMedia != true)
            }
            CommandMenu("Audio") {
                if let model {
                    ForEach(audioMenuRows(model.audioTracks, activeIndex: model.activeAudioTrackIndex)) { row in
                        Button(action: { model.selectAudio(engineIndex: row.engineIndex) }) {
                            Text((row.isSelected ? "\u{2713} " : "") + row.label)
                        }
                    }
                }
            }
            CommandMenu("Subtitles") {
                if let model {
                    ForEach(subtitleMenuRows(model.subtitleTracks,
                                             selectedEngineIndex: model.activeSubtitleTrackIndex,
                                             isActive: model.isSubtitleActive)) { row in
                        Button(action: {
                            switch row.kind {
                            case .off: model.disableSubtitle()
                            case .track(let idx): model.selectSubtitle(engineIndex: idx)
                            }
                        }) {
                            Text((row.isSelected ? "\u{2713} " : "") + row.label)
                        }
                    }
                }
            }
            CommandMenu("Window") {
                Toggle("Always on Top", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Menu("Subtitle Size") {
                    if let model {
                        ForEach(SubtitleSize.allCases) { size in
                            Button(action: { model.setSubtitleSize(size) }) {
                                Text((model.subtitleSize == size ? "\u{2713} " : "") + size.label)
                            }
                        }
                    }
                }
            }
            StatsCommands()
        }

        Window("Stats for Nerds", id: "stats") {
            Group {
                if let model {
                    StatsInspectorView(model: model)
                } else {
                    Text("No player.").frame(minWidth: 320, minHeight: 420)
                }
            }
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.topTrailing)
    }

    private func openFile() {
        guard let model else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .audio]
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.open(url: url) }
        }
    }

    private func openFolderPanel() {
        guard let model else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let bm = BookmarkAccess.bookmark(for: url)
            Task { await model.openFolder(url, bookmarkData: bm) }
        }
    }
}

private struct StatsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Button("Stats for Nerds") { openWindow(id: "stats") }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}
