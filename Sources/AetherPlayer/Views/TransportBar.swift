import SwiftUI
import AetherEngine

struct TransportBar: View {
    let model: PlayerViewModel
    let onTracksTapped: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var scrubbing = false
    @State private var scrubFraction: Double = 0

    /// 0...1 position shown by the slider: the scrub fraction while dragging,
    /// otherwise the live playback fraction.
    private var displayedFraction: Double {
        if scrubbing { return scrubFraction }
        return model.duration > 0 ? model.currentTime / model.duration : 0
    }
    /// Seconds shown by the leading timecode label.
    private var displayedTime: Double {
        scrubbing ? scrubFraction * model.duration : model.currentTime
    }

    var body: some View {
        VStack(spacing: 8) {
            // Scrubber
            HStack(spacing: 10) {
                Text(formatTimecode(displayedTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
                GeometryReader { geo in
                    Slider(
                        value: Binding(
                            get: { displayedFraction },
                            set: { newValue in
                                scrubFraction = newValue
                                model.scrubPreview.update(fraction: newValue,
                                                          durationSeconds: model.duration)
                            }
                        ),
                        in: 0...1,
                        onEditingChanged: { editing in
                            if editing {
                                scrubbing = true
                                scrubFraction = displayedFraction
                                model.scrubPreview.prewarm()
                            } else {
                                scrubbing = false
                                model.seek(to: scrubFraction * model.duration)
                                model.scrubPreview.clear()
                            }
                        }
                    )
                    .overlay(alignment: .bottomLeading) {
                        if scrubbing, let image = model.scrubPreview.previewImage {
                            ScrubThumbnail(image: image, time: scrubFraction * model.duration)
                                .offset(
                                    x: scrubThumbX(fraction: scrubFraction,
                                                   width: geo.size.width,
                                                   thumbWidth: 160),
                                    y: -90
                                )
                        }
                    }
                }
                .frame(height: 20)
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

                Button(action: { onPrevious() }) {
                    Image(systemName: "backward.end.fill").font(.title3)
                }
                .buttonStyle(.plain).foregroundStyle(.white).disabled(!model.hasPrevious)

                Button(action: { onNext() }) {
                    Image(systemName: "forward.end.fill").font(.title3)
                }
                .buttonStyle(.plain).foregroundStyle(.white).disabled(!model.hasNext)

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

                Button(action: { SnapshotSaver.captureAndSave(model: model) }) {
                    Image(systemName: "camera").font(.title3)
                }
                .buttonStyle(.plain)
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

/// The floating keyframe preview shown above the playhead while scrubbing.
private struct ScrubThumbnail: View {
    let image: CGImage
    let time: Double

    var body: some View {
        VStack(spacing: 2) {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            Text(formatTimecode(time))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(.black.opacity(0.6), in: Capsule())
        }
        .shadow(radius: 6)
    }
}
