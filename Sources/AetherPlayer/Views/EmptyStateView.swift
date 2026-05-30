import SwiftUI

struct EmptyStateView: View {
    let isDropTargeted: Bool
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(isDropTargeted ? 0.95 : 0.45))
            Text(isDropTargeted ? "Release to load" : "Drop a video here")
                .font(.title2)
                .foregroundStyle(.white.opacity(isDropTargeted ? 0.95 : 0.65))
            Button("Open File\u{2026}", action: onOpen)
                .controlSize(.large)
            Text("MKV, MP4, WebM, MPEG-TS, AVI, OGG, FLV")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
