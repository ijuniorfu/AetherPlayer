import SwiftUI

enum DocumentOpen {
    /// Opens `url` while holding its security scope only across the
    /// `open(url:)` call: the engine acquires its own file handle during
    /// `load`, so scope is released as soon as that call returns, not held
    /// for the session. Reopening a Recent goes through its persisted
    /// bookmark (BookmarkAccess) instead of this transient scope.
    @MainActor
    static func open(_ url: URL, model: PlayerViewModel) {
        let didScope = url.startAccessingSecurityScopedResource()
        Task {
            await model.open(url: url)
            if didScope { url.stopAccessingSecurityScopedResource() }
        }
    }

    /// Handle a .fileImporter result: forwards its first URL to open(_:model:).
    @MainActor
    static func handlePicked(_ result: Result<[URL], Error>, model: PlayerViewModel) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        open(url, model: model)
    }
}
