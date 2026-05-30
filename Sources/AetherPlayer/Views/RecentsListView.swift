import SwiftUI

struct RecentsListView: View {
    let items: [RecentItem]
    let onOpen: (RecentItem) -> Void
    let onRemove: (RecentItem) -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent").font(.headline).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button("Clear All", action: onClearAll)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.white.opacity(0.5))
            }
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        RecentRow(item: item, onOpen: { onOpen(item) }, onRemove: { onRemove(item) })
                    }
                }
            }
            // Hug the content for a few entries, then cap and scroll, so the box
            // does not balloon into empty space with only one or two recents.
            .frame(height: min(CGFloat(items.count) * 44, 220))
        }
        .frame(maxWidth: 460)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct RecentRow: View {
    let item: RecentItem
    let onOpen: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).foregroundStyle(.white).lineLimit(1)
                    ProgressView(value: item.progress)
                        .frame(height: 2)
                        .tint(.white.opacity(0.6))
                }
                Spacer()
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.white.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
