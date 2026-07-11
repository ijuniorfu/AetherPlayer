import SwiftUI

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
        // .fileImporter added in Task 1.2, .sheet added in Task 1.3
    }
}
