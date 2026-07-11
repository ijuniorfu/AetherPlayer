import SwiftUI

@main
struct AetherPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("AetherPlayer iOS")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .foregroundStyle(.white)
                .ignoresSafeArea()
        }
    }
}
