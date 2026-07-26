import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    let model: PlayerViewModel
    @State private var showFileImporter = false
    @State private var showFolderImporter = false
    @State private var showURLSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                openActions
                    .buttonStyle(.borderedProminent)
                    .padding()
                RecentsGrid(model: model)
            }
            .navigationTitle("AetherPlayer")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .audio],
            allowsMultipleSelection: false
        ) { result in
            DocumentOpen.handlePicked(result, model: model)
        }
        .fileImporter(
            isPresented: $showFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            DocumentOpen.openFolder(result, model: model)
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
        Button { showFileImporter = true } label: {
            openLabel("Open File", systemImage: "folder", fullWidth: fullWidth)
        }
        Button { showFolderImporter = true } label: {
            openLabel("Open Folder", systemImage: "folder.badge.plus", fullWidth: fullWidth)
        }
        Button { showURLSheet = true } label: {
            openLabel("Open URL", systemImage: "link", fullWidth: fullWidth)
        }
    }

    private func openLabel(_ title: LocalizedStringKey, systemImage: String, fullWidth: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(fullWidth ? nil : 1)
            .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
    }
}
