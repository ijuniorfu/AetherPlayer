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
                    Button(action: { model.toggleMute() }) {
                        Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.7))
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

                Menu {
                    ForEach(PlayerViewModel.availableRates, id: \.self) { r in
                        Button {
                            model.setRate(r)
                        } label: {
                            Text((model.rate == r ? "\u{2713} " : "") + rateLabel(r))
                        }
                    }
                } label: {
                    Text(rateLabel(model.rate))
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: Capsule())
                        .foregroundStyle(.white)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

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

    /// "1x", "1.5x", "0.5x" -- drops trailing ".0" for whole rates.
    private func rateLabel(_ r: Float) -> String {
        if r == r.rounded() {
            return "\(Int(r))x"
        }
        return "\(String(format: "%g", r))x"
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
