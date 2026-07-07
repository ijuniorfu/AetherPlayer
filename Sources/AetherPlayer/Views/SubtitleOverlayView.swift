import SwiftUI
import AetherEngine

/// Observes the subtitle state in isolation so the parent `PlayerContainerView`
/// body does not depend on the ~10 Hz `subtitleTime` clock. Reading that clock
/// high in the tree made the whole container ZStack (engine surface, click /
/// mouse / key NSViews, popover) re-evaluate 10x/sec during undisturbed
/// playback. Here the 10 Hz read is confined to this small view, and gated on
/// non-empty cues: with subtitles off the body reads neither `subtitleTime` nor
/// size, so idle playback establishes no per-tick dependency at all. (issue #2)
struct SubtitleOverlay: View {
    let model: PlayerViewModel

    var body: some View {
        let cues = model.subtitleCues
        if cues.isEmpty {
            Color.clear
        } else {
            SubtitleOverlayView(cues: cues,
                                subtitleTime: model.subtitleTime,
                                userScale: model.subtitleSize.scale)
        }
    }
}

/// Renders subtitle cues active at the current playback time on top of
/// the video. Text cues: centered semi-transparent box near the bottom.
/// Image cues (PGS / DVB): bitmap positioned by its normalized rect.
struct SubtitleOverlayView: View {
    let cues: [SubtitleCue]
    /// Source-PTS clock (engine.sourceTime), the axis cue start/end times live on. NOT currentTime,
    /// which is shifted by the disc clip-0 STC origin and would offset cues on Blu-ray. (#112)
    let subtitleTime: Double
    /// User size multiplier (from PlayerViewModel.subtitleSize.scale).
    var userScale: CGFloat = 1.0

    private var activeCues: [SubtitleCue] {
        cues.filter { subtitleTime >= $0.startTime && subtitleTime <= $0.endTime }
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
            .font(.system(size: subtitleFontSize(surfaceHeight: size.height, userScale: userScale),
                          weight: .medium))
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
