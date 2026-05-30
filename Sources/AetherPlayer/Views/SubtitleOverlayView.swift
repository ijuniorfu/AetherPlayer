import SwiftUI
import AetherEngine

/// Renders subtitle cues active at the current playback time on top of
/// the video. Text cues: centered semi-transparent box near the bottom.
/// Image cues (PGS / DVB): bitmap positioned by its normalized rect.
struct SubtitleOverlayView: View {
    let cues: [SubtitleCue]
    let currentTime: Double

    private var activeCues: [SubtitleCue] {
        cues.filter { currentTime >= $0.startTime && currentTime <= $0.endTime }
    }

    var body: some View {
        GeometryReader { geo in
            Color.clear.overlay(alignment: .topLeading) {
                ForEach(activeCues, id: \.id) { cue in
                    switch cue.body {
                    case .text(let text):
                        textCue(text, in: geo.size)
                    case .image(let image):
                        imageCue(image, in: geo.size)
                    }
                }
            }
        }
    }

    private func textCue(_ text: String, in size: CGSize) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: max(0, size.width - 160))
            .frame(width: size.width, height: size.height, alignment: .bottom)
            .padding(.bottom, 48)
    }

    private func imageCue(_ image: SubtitleImage, in size: CGSize) -> some View {
        let rect = CGRect(x: image.position.minX * size.width,
                          y: image.position.minY * size.height,
                          width: image.position.width * size.width,
                          height: image.position.height * size.height)
        return Image(decorative: image.cgImage, scale: 1.0)
            .resizable()
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }
}
