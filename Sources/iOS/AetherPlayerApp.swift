import SwiftUI

@main
struct AetherPlayerApp: App {
    @State private var model: PlayerViewModel? = { try? PlayerViewModel() }()

    var body: some Scene {
        WindowGroup {
            if let model {
                RootView(model: model)
                    .onOpenURL { url in
                        DocumentOpen.open(url, model: model)
                    }
            } else {
                Text("AetherEngine failed to initialize.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black).foregroundStyle(.white).ignoresSafeArea()
            }
        }
    }
}
