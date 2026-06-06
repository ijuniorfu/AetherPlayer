import SwiftUI
import AppKit
import AetherEngine

/// Full-window presentation for audio-only playback: a large centered
/// cover over a blurred, darkened copy of the same cover, with title /
/// artist / album below. Falls back to a music glyph on an Aether-brand
/// gradient when the source has no embedded artwork. (The transport bar
/// is added by a later task and stays visible; no auto-hide.)
struct NowPlayingView: View {
    let model: PlayerViewModel

    /// Embedded cover decoded once per artwork-bytes change (see .task below).
    @State private var cover: NSImage?
    @State private var showTracks = false
    @State private var scrubbing = false

    var body: some View {
        ZStack {
            if let cover {
                Image(nsImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60)
                    .overlay(Color.black.opacity(0.55))
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color.aetherBlue.opacity(0.35), Color.aetherPurple.opacity(0.25), .black],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                Spacer()
                cover(cover)
                metadataBlock
                Spacer()
            }
            .padding(.bottom, 80) // leave room for the transport bar
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: model.metadata?.artworkData) {
            cover = model.metadata?.artworkData.flatMap { NSImage(data: $0) }
        }
        .overlay(alignment: .bottom) {
            TransportBar(
                model: model,
                onTracksTapped: { showTracks.toggle() },
                onPrevious: { Task { await model.playPrevious() } },
                onNext: { Task { await model.playNext() } },
                scrubbing: $scrubbing
            )
            .popover(isPresented: $showTracks, arrowEdge: .bottom) {
                TracksPopover(model: model)
            }
        }
        .overlay { KeyCatcherView(onKey: handleKey).allowsHitTesting(false) }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 49: model.primaryAction(); return true              // Space
        case 123: model.seek(by: -10); return true               // Left
        case 124: model.seek(by: 10); return true                // Right
        case 126: model.adjustVolume(by: 0.05); return true      // Up
        case 125: model.adjustVolume(by: -0.05); return true     // Down
        case 46: model.toggleMute(); return true                 // M
        case 53: model.stop(); return true                       // Esc
        default: return false
        }
    }

    @ViewBuilder
    private func cover(_ image: NSImage?) -> some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.06))
                    Image(systemName: "music.note")
                        .font(.system(size: 96, weight: .light))
                        .foregroundStyle(LinearGradient.aetherAccent)
                }
            }
        }
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
    }

    private var metadataBlock: some View {
        VStack(spacing: 6) {
            Text(nowPlayingTitle(metadata: model.metadata, url: model.loadedURL))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let secondary = nowPlayingSubtitle(metadata: model.metadata) {
                Text(secondary)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 40)
    }
}
