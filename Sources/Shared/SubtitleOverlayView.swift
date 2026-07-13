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
                                userScale: model.subtitleSize.scale,
                                videoSize: model.videoSize)
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
    /// Coded video size, for aspect-fitting bitmap (PGS/DVB) cues into the letterboxed video rect.
    var videoSize: CGSize = .zero

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
        // Bitmap cue positions are normalized to the subtitle composition canvas (often 16:9 even
        // when the video is scope-cropped). Map the canvas onto the aspect-fit video rect so cues
        // land where they were authored (including the letterbox bar) instead of stretching to the
        // full overlay bounds. On a matching aspect this reduces to the old full-bounds layout; in
        // portrait it pins cues to the video band, not the screen bottom.
        let videoRect = Self.aspectFitRect(videoSize: videoSize, in: size)
        let canvas = image.canvasSize
        let canvasRect: CGRect
        if videoRect.width > 0, canvas.width > 0, canvas.height > 0, videoSize.width > 0 {
            let scale = videoRect.width / videoSize.width
            let w = canvas.width * scale
            let h = canvas.height * scale
            canvasRect = CGRect(x: videoRect.midX - w / 2, y: videoRect.midY - h / 2, width: w, height: h)
        } else {
            canvasRect = CGRect(origin: .zero, size: size)
        }
        let frameW = image.position.width * canvasRect.width
        let frameH = image.position.height * canvasRect.height
        let originX = canvasRect.minX + image.position.minX * canvasRect.width
        let originY = canvasRect.minY + image.position.minY * canvasRect.height
        return Image(decorative: image.cgImage, scale: 1.0)
            .resizable()
            .interpolation(.high)
            .frame(width: frameW, height: frameH)
            .offset(x: originX, y: originY)
    }

    /// Aspect-fit rect of the video plane within the overlay bounds. Full bounds when the video
    /// dimensions are unknown (pre-load or older cues).
    private static func aspectFitRect(videoSize: CGSize, in bounds: CGSize) -> CGRect {
        guard videoSize.width > 0, videoSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return CGRect(origin: .zero, size: bounds)
        }
        let videoAspect = videoSize.width / videoSize.height
        let boundsAspect = bounds.width / bounds.height
        if boundsAspect > videoAspect {
            let w = bounds.height * videoAspect
            return CGRect(x: (bounds.width - w) / 2, y: 0, width: w, height: bounds.height)
        } else {
            let h = bounds.width / videoAspect
            return CGRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
        }
    }
}
