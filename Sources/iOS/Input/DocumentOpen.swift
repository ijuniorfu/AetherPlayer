import SwiftUI

enum DocumentOpen {
    /// Handle a .fileImporter result: hold security scope, then open.
    /// The VM records a bookmark (BookmarkAccess) for later reopen; we keep
    /// scope held for the session and stop it when playback stops.
    @MainActor
    static func handlePicked(_ result: Result<[URL], Error>, model: PlayerViewModel) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let didScope = url.startAccessingSecurityScopedResource()
        Task {
            await model.open(url: url)
            // The VM persists an app-scoped bookmark inside open(); once loaded,
            // release this transient scope. Reopen goes through openRecent's bookmark.
            if didScope { url.stopAccessingSecurityScopedResource() }
        }
    }
}
