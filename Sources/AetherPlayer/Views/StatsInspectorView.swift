import SwiftUI
import AetherEngine

/// Live playback statistics, QuickTime-Inspector style. Observes the engine's
/// dedicated diagnostics object (1 Hz) so per-second telemetry does not churn
/// views bound to the engine itself, plus the @Observable PlayerViewModel.
struct StatsInspectorView: View {
    let model: PlayerViewModel
    @ObservedObject private var diagnostics: EngineDiagnostics

    init(model: PlayerViewModel) {
        self.model = model
        _diagnostics = ObservedObject(wrappedValue: model.engine.diagnostics)
    }

    var body: some View {
        let tele = diagnostics.liveTelemetry
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("Source") {
                    row("File", model.loadedURL?.lastPathComponent ?? "\u{2014}")
                    row("Duration", formatTimecode(model.duration))
                    row("Live", model.engine.isLive ? "Yes" : "No")
                }
                section("Video") {
                    row("Resolution", formatResolution(
                        width: Int(model.engine.sourceVideoWidth),
                        height: Int(model.engine.sourceVideoHeight)))
                    row("HDR", videoFormatLabel(model.engine.sourceVideoFormat))
                    row("Decoder", model.engine.activeVideoDecoder ?? "\u{2014}")
                    row("Backend", formatBackend(model.backend))
                }
                section("Audio") {
                    row("Decoder", model.engine.activeAudioDecoder ?? "\u{2014}")
                    row("Tracks", "\(model.audioTracks.count)")
                }
                section("Live") {
                    row("FPS", formatFps(tele?.observedFps))
                    row("Dropped frames", formatDroppedFrames(tele?.droppedFrameCount))
                    row("Bitrate (inst)", formatMbps(tele?.instantBitrateMbps))
                    row("Bitrate (avg)", formatMbps(tele?.averageBitrateMbps))
                    row("Buffer ahead", formatSeconds(tele?.forwardBufferSeconds))
                    row("A/V sync", tele.map { formatSeconds($0.avSyncGapMs.map { $0 / 1000 }) } ?? "\u{2014}")
                    row("Memory", tele.map { formatMemoryMB($0.rssMb) } ?? "\u{2014}")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 320, minHeight: 420)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value).font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}
