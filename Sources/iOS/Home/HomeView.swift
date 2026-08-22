import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    /// What the importer is currently asking for. Two `.fileImporter` modifiers on
    /// one view do not both work, the later one wins and the earlier never presents,
    /// so file and folder share a single importer and swap its content types.
    private enum ImportKind {
        case media, folder

        var contentTypes: [UTType] {
            switch self {
            case .media: [.movie, .video, .audio]
            case .folder: [.folder]
            }
        }
    }

    let model: PlayerViewModel
    @State private var importKind: ImportKind = .media
    @State private var showImporter = false
    @State private var showURLSheet = false
    @State private var diagnosticsSnapshot: DiagnosticsSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                openActions
                    .buttonStyle(.borderedProminent)
                    .padding()
                RecentsGrid(model: model)
            }
            .navigationTitle("AetherPlayer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // The counterpart to the macOS Help-menu entries: a playback report costs one
                    // share sheet instead of a debugger.
                    Button {
                        diagnosticsSnapshot = DiagnosticsLog.shared.exportSnapshot()
                            .map(DiagnosticsSnapshot.init)
                    } label: {
                        Label("Share Diagnostics Log", systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
        }
        .sheet(item: $diagnosticsSnapshot) { DiagnosticsShareSheet(url: $0.url) }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importKind.contentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch importKind {
            case .media: DocumentOpen.handlePicked(result, model: model)
            case .folder: DocumentOpen.openFolder(result, model: model)
            }
        }
        .sheet(isPresented: $showURLSheet) { OpenURLSheet(model: model) }
        .overlay(alignment: .bottom) {
            // Remote opens can take 10-20 s (tuner tune-in + stream probe); without
            // feedback the app reads as hung. Player cover only opens once loaded.
            if model.state == .loading && !model.hasMedia {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Opening stream…")
                    Button("Cancel") { model.cancelLoading() }
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.state == .loading)
        .alert(
            "Playback Error",
            isPresented: Binding(
                get: { model.loadError != nil },
                set: { if !$0 { model.clearLoadError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.loadError ?? "")
        }
    }

    /// Three open actions side by side where the width allows (iPad, landscape),
    /// stacked full width where it does not. A plain HStack wraps the labels on
    /// iPhone portrait, since three icon-plus-text buttons do not fit ~358 pt.
    private var openActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                openButtons(fullWidth: false)
            }
            VStack(spacing: 12) {
                openButtons(fullWidth: true)
            }
        }
    }

    @ViewBuilder
    private func openButtons(fullWidth: Bool) -> some View {
        Button { present(.media) } label: {
            openLabel("Open File", systemImage: "folder", fullWidth: fullWidth)
        }
        Button { present(.folder) } label: {
            openLabel("Open Folder", systemImage: "folder.badge.plus", fullWidth: fullWidth)
        }
        Button { showURLSheet = true } label: {
            openLabel("Open URL", systemImage: "link", fullWidth: fullWidth)
        }
    }

    private func present(_ kind: ImportKind) {
        importKind = kind
        showImporter = true
    }

    private func openLabel(_ title: LocalizedStringKey, systemImage: String, fullWidth: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(fullWidth ? nil : 1)
            .frame(maxWidth: fullWidth ? .infinity : nil)
    }
}
