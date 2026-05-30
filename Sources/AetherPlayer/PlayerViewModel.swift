import Foundation
import Combine
import AppKit
import AetherEngine

@Observable
@MainActor
final class PlayerViewModel {
    let engine: AetherEngine

    // Mirrored engine state (kept in sync via Combine).
    private(set) var state: PlaybackState = .idle
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var audioTracks: [TrackInfo] = []
    private(set) var subtitleTracks: [TrackInfo] = []
    private(set) var activeAudioTrackIndex: Int?
    private(set) var backend: PlaybackBackend = .none
    private(set) var subtitleCues: [SubtitleCue] = []
    private(set) var isSubtitleActive: Bool = false

    // Host-only state.
    private(set) var loadedURL: URL?
    private(set) var loadError: String?
    /// Engine index of the subtitle track the user picked (no published
    /// active-subtitle index exists, so we track it here).
    private(set) var selectedSubtitleIndex: Int?

    var volume: Float {
        get { engine.volume }
        set { engine.volume = newValue }
    }

    var isPlaying: Bool { state == .playing }
    var hasMedia: Bool { loadedURL != nil }

    private var cancellables = Set<AnyCancellable>()

    init() throws {
        self.engine = try AetherEngine()
        bind()
    }

    private func bind() {
        engine.$state.receive(on: RunLoop.main).sink { [weak self] in self?.state = $0 }.store(in: &cancellables)
        engine.$currentTime.receive(on: RunLoop.main).sink { [weak self] in self?.currentTime = $0 }.store(in: &cancellables)
        engine.$duration.receive(on: RunLoop.main).sink { [weak self] in self?.duration = $0 }.store(in: &cancellables)
        engine.$audioTracks.receive(on: RunLoop.main).sink { [weak self] in self?.audioTracks = $0 }.store(in: &cancellables)
        engine.$subtitleTracks.receive(on: RunLoop.main).sink { [weak self] in self?.subtitleTracks = $0 }.store(in: &cancellables)
        engine.$activeAudioTrackIndex.receive(on: RunLoop.main).sink { [weak self] in self?.activeAudioTrackIndex = $0 }.store(in: &cancellables)
        engine.$playbackBackend.receive(on: RunLoop.main).sink { [weak self] in self?.backend = $0 }.store(in: &cancellables)
        engine.$subtitleCues.receive(on: RunLoop.main).sink { [weak self] in self?.subtitleCues = $0 }.store(in: &cancellables)
        engine.$isSubtitleActive.receive(on: RunLoop.main).sink { [weak self] in self?.isSubtitleActive = $0 }.store(in: &cancellables)
    }

    func open(url: URL) async {
        loadError = nil
        do {
            try await engine.load(url: url)
            engine.play()
            loadedURL = url
            selectedSubtitleIndex = nil
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            loadError = "Could not play \(url.lastPathComponent): \(error.localizedDescription)"
            loadedURL = nil
        }
    }

    func togglePlayPause() {
        switch state {
        case .playing: engine.pause()
        case .paused: engine.play()
        default: break
        }
    }

    func stop() {
        engine.stop()
        loadedURL = nil
        loadError = nil
    }

    func seek(by delta: Double) {
        let target = max(0, min(duration, currentTime + delta))
        Task { await engine.seek(to: target) }
    }

    func seek(to seconds: Double) {
        Task { await engine.seek(to: seconds) }
    }

    func selectAudio(engineIndex: Int) {
        engine.selectAudioTrack(index: engineIndex)
    }

    func selectSubtitle(engineIndex: Int) {
        engine.selectSubtitleTrack(index: engineIndex)
        selectedSubtitleIndex = engineIndex
    }

    func disableSubtitle() {
        engine.clearSubtitle()
        selectedSubtitleIndex = nil
    }

    func loadSidecarSubtitle(url: URL) {
        engine.selectSidecarSubtitle(url: url)
    }
}
