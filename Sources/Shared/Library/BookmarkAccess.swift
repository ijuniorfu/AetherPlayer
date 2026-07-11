import Foundation

/// Security-scoped bookmark helpers. Under the App Sandbox a URL granted by
/// an open panel / drop / Finder open is only reachable for this launch;
/// a security-scoped bookmark lets us reopen it later.
enum BookmarkAccess {
    /// Create security-scoped bookmark data for a file or folder.
    static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope,
                              includingResourceValuesForKeys: nil,
                              relativeTo: nil)
    }
}

/// Resolves a bookmark and holds its security scope until `stop()` (or deinit).
/// Use one per active file/folder; stop it when you load something else.
final class ScopedResource {
    let url: URL
    let isStale: Bool
    private var active: Bool

    init?(bookmark data: Data) {
        var stale = false
        guard let resolved = try? URL(resolvingBookmarkData: data,
                                      options: .withSecurityScope,
                                      relativeTo: nil,
                                      bookmarkDataIsStale: &stale) else { return nil }
        guard resolved.startAccessingSecurityScopedResource() else { return nil }
        self.url = resolved
        self.isStale = stale
        self.active = true
    }

    func stop() {
        guard active else { return }
        url.stopAccessingSecurityScopedResource()
        active = false
    }

    deinit { stop() }
}
