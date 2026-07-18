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
                if model.isAudioOnly {
                    NowPlayingView(model: model)
                        .ignoresSafeArea()
                } else {
                    PlayerContainerView(model: model)
                        .ignoresSafeArea()
                }
            } else {
                EmptyStateView(
                    isDropTargeted: isDropTargeted,
                    onOpen: openPanel,
                    recents: model.recents.items,
                    thumbnails: model.recentsThumbnails,
                    onOpenRecent: { item in Task { await model.openRecent(item) } },
                    onRemoveRecent: { model.recents.remove($0) },
                    onClearRecents: { model.recents.clearAll() }
                )
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

            if let msg = model.resumeMessage {
                VStack {
                    Spacer()
                    ResumeToastView(message: msg, onStartOver: { model.startOver() })
                        .padding(.bottom, 90)
                }
                .transition(.opacity)
                .task(id: msg) {
                    try? await Task.sleep(for: .seconds(6))
                    model.dismissResumeMessage()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.loadError)
        .animation(.easeInOut(duration: 0.25), value: model.resumeMessage)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    if isDir.boolValue {
                        let bm = BookmarkAccess.bookmark(for: url)
                        await model.openFolder(url, bookmarkData: bm)
                    } else if Self.subtitleExtensions.contains(url.pathExtension.lowercased()), model.hasMedia {
                        // A subtitle file dropped onto a playing video attaches as
                        // a external track; anything else loads as a new video.
                        model.loadExternalSubtitle(url: url)
                    } else {
                        await model.open(url: URL(string: "http://127.0.0.1:9976/proxy.iso?url=https%3A%2F%2F223-109-125-232-v3.pd1.cjjd19.com%2F1135-vip-download-cdn.123295.com%2F123-332%2F7da1cbc1%2F1850695235-0%2F7da1cbc117f8193256c41efca255994c%2Fc-m101%3Fv%3D5%26t%3D1784954769%26r%3DQS4BDA%26bzc%3D1%26bzs%3D313832373731343731333a323a313a3334393630323434373336%26ur%3Dvplgavagpigbl%26urn%3D1%26s%3D1784954769eb5bef710f8fda9f69f82d42254ad0ed%26bzp%3D0%26bi%3D876316113%26filename%3D%E5%94%AC%E8%83%86%E7%89%B9%E5%B7%A5%2B%255B%E7%BE%8E%E7%89%88%E5%8E%9F%E7%9B%98%2B%E5%8E%9F%E7%94%9F%E4%B8%AD%E5%AD%97%2BDIY%E4%B8%8A%E8%AF%91%E5%85%AC%E6%98%A0%E5%9B%BD%E8%AF%AD%2B%E5%9B%BD%E9%85%8D%E7%AE%80%E4%BD%93%E5%AD%97%E5%B9%95%255D.The%2BMan%2Bfrom%2BToronto%2B2022%2BBluRay%2B1080p%2BAVC%2BDTS-HD%2BMA5.1-TYZH%2540HDSky%255B32.56GB%255D%25281%2529.iso%26x-mf-biz-cid%3D04610814-9aae-4ac0-8b1d-b656c950cc88-5baabb%26auto_redirect%3D0%26ndcp%3D1%26cache_type%3D1")!)
                    }
                }
            }
            return true
        }
        .onChange(of: model.loadedURL) { _, _ in updateWindowTitle() }
        .onChange(of: model.metadata) { _, _ in updateWindowTitle() }
        .onChange(of: model.isAudioOnly) { _, _ in updateWindowTitle() }
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

    private func updateWindowTitle() {
        NSApp.keyWindow?.title = windowTitle(
            metadata: model.metadata, url: model.loadedURL, isAudio: model.isAudioOnly)
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .audio, .discImage]
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.open(url: url) }
        }
    }
}
