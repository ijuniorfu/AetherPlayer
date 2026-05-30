import SwiftUI
import AetherEngine

struct TransportBar: View {
    let model: PlayerViewModel
    let onTracksTapped: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Scrubber
            HStack(spacing: 10) {
                Text(formatTimecode(model.currentTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
                Slider(
                    value: Binding(
                        get: { model.duration > 0 ? model.currentTime : 0 },
                        set: { model.seek(to: $0) }
                    ),
                    in: 0...max(model.duration, 0.01)
                )
                Text(formatTimecode(model.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
            }
            // Controls row
            HStack(spacing: 16) {
                Button(action: { model.primaryAction() }) {
                    Image(systemName: playButtonSymbol)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill").foregroundStyle(.white.opacity(0.7))
                    Slider(value: Binding(get: { Double(model.volume) },
                                          set: { model.volume = Float($0) }),
                           in: 0...1)
                        .frame(width: 90)
                }

                Spacer()

                Text(backendBadge)
                    .font(.system(.caption2, design: .monospaced))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)

                Button(action: onTracksTapped) {
                    Image(systemName: "captions.bubble").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var playButtonSymbol: String {
        if model.isEnded { return "arrow.counterclockwise" }
        return model.isPlaying ? "pause.fill" : "play.fill"
    }

    private var backendBadge: String {
        switch model.backend {
        case .native: return "native"
        case .software: return "sw"
        case .aether: return "aether"
        case .none: return ""
        }
    }
}
