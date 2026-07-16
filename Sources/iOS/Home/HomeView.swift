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
                HStack {
                    Button { showFileImporter = true } label: {
                        Label("Open File", systemImage: "folder")
                    }
                    Button { showFolderImporter = true } label: {
                        Label("Open Folder", systemImage: "folder.badge.plus")
                    }
                    Button { showURLSheet = true } label: {
                        Label("Open URL", systemImage: "link")
                    }
                }
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
}
