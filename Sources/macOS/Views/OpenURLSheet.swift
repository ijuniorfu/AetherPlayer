import SwiftUI

struct OpenURLSheet: View {
    let model: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var openAsLive = false
    @FocusState private var isURLFieldFocused: Bool

    private var validURL: URL? { MediaURLValidation.normalized(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open URL")
                .font(.title2.bold())

            TextField("https://example.com/video.mkv", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isURLFieldFocused)

            Toggle("Live stream (tuner / IPTV)", isOn: $openAsLive)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Play") {
                    guard let url = validURL else { return }
                    Task { await model.open(url: url, forceLive: openAsLive) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validURL == nil)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear { isURLFieldFocused = true }
    }
}
