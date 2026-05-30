import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AetherEngine

struct TracksPopover: View {
    let model: PlayerViewModel

    private var audioRows: [AudioMenuRow] {
        audioMenuRows(model.audioTracks, activeIndex: model.activeAudioTrackIndex)
    }
    private var subtitleRows: [SubtitleMenuRow] {
        subtitleMenuRows(model.subtitleTracks,
                         selectedEngineIndex: model.selectedSubtitleIndex,
                         isActive: model.isSubtitleActive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !audioRows.isEmpty {
                Text("Audio").font(.headline)
                ForEach(audioRows) { row in
                    rowButton(row.label, selected: row.isSelected) {
                        model.selectAudio(engineIndex: row.engineIndex)
                    }
                }
                Divider()
            }
            Text("Subtitles").font(.headline)
            ForEach(subtitleRows) { row in
                rowButton(row.label, selected: row.isSelected) {
                    switch row.kind {
                    case .off: model.disableSubtitle()
                    case .track(let idx): model.selectSubtitle(engineIndex: idx)
                    }
                }
            }
            Button("Load Subtitle File\u{2026}", action: loadSidecar)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 280)
    }

    @ViewBuilder
    private func rowButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                Text(label)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func loadSidecar() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "srt") ?? .plainText,
                                     UTType(filenameExtension: "ass") ?? .plainText,
                                     UTType(filenameExtension: "vtt") ?? .plainText]
        if panel.runModal() == .OK, let url = panel.url {
            model.loadSidecarSubtitle(url: url)
        }
    }
}
