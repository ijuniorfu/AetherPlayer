import Foundation

/// Container extensions AetherPlayer treats as playable, lowercased.
let playableExtensions: Set<String> = [
    "mkv", "mp4", "m4v", "mov", "webm", "ts", "m2ts", "avi", "ogv", "ogg", "flv"
]

/// Filters a directory listing to playable files and sorts them the way
/// Finder does (so ep2 precedes ep10).
func playableFiles(in urls: [URL]) -> [URL] {
    urls
        .filter { playableExtensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

/// An ordered list of files with a cursor. Pure value type.
struct Playlist: Equatable {
    private(set) var items: [URL]
    private(set) var currentIndex: Int

    var current: URL? { items.indices.contains(currentIndex) ? items[currentIndex] : nil }
    var hasNext: Bool { currentIndex + 1 < items.count }
    var hasPrevious: Bool { currentIndex - 1 >= 0 }

    func index(of url: URL) -> Int? {
        items.firstIndex { $0.standardizedFileURL == url.standardizedFileURL }
    }

    mutating func next() -> URL? {
        guard hasNext else { return nil }
        currentIndex += 1
        return items[currentIndex]
    }

    mutating func previous() -> URL? {
        guard hasPrevious else { return nil }
        currentIndex -= 1
        return items[currentIndex]
    }
}
