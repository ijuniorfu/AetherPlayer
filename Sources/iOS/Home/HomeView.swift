import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    let model: PlayerViewModel
    @State private var showFileImporter = false
    @State private var showURLSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack {
                    Button { showFileImporter = true } label: {
                        Label("Open File", systemImage: "folder")
                    }
                    Button { showURLSheet = true } label: {
                        Label("Open URL", systemImage: "link")
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
                // RecentsGrid(model: model) added in Task 1.4
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
        // .sheet added in Task 1.3
    }
}
