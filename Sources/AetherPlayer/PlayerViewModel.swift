import Foundation
import Combine
import AppKit
import CoreGraphics
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
    private(set) var metadata: MediaMetadata?

    // Host-only state.
    private(set) var loadedURL: URL?
    private(set) var loadError: String?
    /// Engine index of the subtitle track the user picked (no published
    /// active-subtitle index exists, so we track it here).
    private(set) var selectedSubtitleIndex: Int?

    private(set) var playlist: Playlist?
    private var folderScoped: ScopedResource?
    var hasNext: Bool { playlist?.hasNext ?? false }
    var hasPrevious: Bool { playlist?.hasPrevious ?? false }

    let recents = RecentsStore()
    /// One frame extractor per playback session, built from the playing file
    /// and shared by scrub preview and snapshot. Released (and shut down) on
    /// the next load and on stop().
    @ObservationIgnored private var frameExtractor: FrameExtractor?
    /// Scrub-preview source, reconfigured on each load.
    let scrubPreview = ScrubPreviewProvider()
    /// Decode + disk-cached thumbnails for the recents list.
    let recentsThumbnails = RecentsThumbnailProvider()
    private var scoped: ScopedResource?
    /// Set briefly after a resume so the UI can offer "Start over".
    private(set) var resumeMessage: String?
    private var lastPersist: Date = .distantPast

    var volume: Float {
        get { engine.volume }
        set {
            let clamped = max(0, min(1, newValue))
            engine.volume = clamped
            UserDefaults.standard.set(clamped, forKey: "player.volume")
        }
    }

    /// Playback speed. The engine has no published rate, so we mirror it
    /// locally; reset to 1x on each new load.
    private(set) var rate: Float = 1.0

    /// Volume captured before muting, so unmute restores it.
    private var preMuteVolume: Float?
    var isMuted: Bool { volume == 0 }

    /// Held while playing to keep the display and system awake during
    /// playback; released as soon as playback is not active.
    private var sleepAssertion: NSObjectProtocol?

    var isPlaying: Bool { state == .playing }
    var hasMedia: Bool { loadedURL != nil }
    /// A loaded file that has played to its natural end. The engine flips
    /// `state` back to `.idle` on end-of-stream (both backends), and our
    /// `loadedURL` only clears on `stop()`, so "loaded but idle" means ended.
    var isEnded: Bool { hasMedia && state == .idle }
    /// True when the session is presenting as audio-only (see isAudioPlayback).
    var isAudioOnly: Bool { isAudioPlayback(backend: backend, url: loadedURL) }

    private var cancellables = Set<AnyCancellable>()

    init() throws {
        self.engine = try AetherEngine()
        bind()
        if UserDefaults.standard.object(forKey: "player.volume") != nil {
            engine.volume = UserDefaults.standard.float(forKey: "player.volume")
        }
    }

    private func bind() {
        engine.$state.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.state = $0
            self?.updateSleepAssertion()
            if $0 == .idle, let url = self?.loadedURL, self?.hasMedia == true {
                self?.recents.markFinished(url)   // reached natural end
                if self?.playlist?.hasNext == true {
                    Task { @MainActor in await self?.playNext() }
                }
            }
        }.store(in: &cancellables)
        engine.$currentTime.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.currentTime = $0
            self?.persistPositionThrottled()
        }.store(in: &cancellables)
        engine.$duration.receive(on: DispatchQueue.main).sink { [weak self] in self?.duration = $0 }.store(in: &cancellables)
        engine.$audioTracks.receive(on: DispatchQueue.main).sink { [weak self] in self?.audioTracks = $0 }.store(in: &cancellables)
        engine.$subtitleTracks.receive(on: DispatchQueue.main).sink { [weak self] in self?.subtitleTracks = $0 }.store(in: &cancellables)
        engine.$activeAudioTrackIndex.receive(on: DispatchQueue.main).sink { [weak self] in self?.activeAudioTrackIndex = $0 }.store(in: &cancellables)
        engine.$playbackBackend.receive(on: DispatchQueue.main).sink { [weak self] in self?.backend = $0 }.store(in: &cancellables)
        engine.$subtitleCues.receive(on: DispatchQueue.main).sink { [weak self] in self?.subtitleCues = $0 }.store(in: &cancellables)
        engine.$isSubtitleActive.receive(on: DispatchQueue.main).sink { [weak self] in self?.isSubtitleActive = $0 }.store(in: &cancellables)
        engine.$metadata.receive(on: DispatchQueue.main).sink { [weak self] in self?.metadata = $0 }.store(in: &cancellables)
    }

    func open(url: URL) async {
        await openInternal(url: url, recordPlaylistRelative: true)
    }

    /// Shared open path. Fresh opens make a new bookmark; reopening from a recent
    /// resolves a ScopedResource first (see openRecent).
    private func openInternal(url: URL, recordPlaylistRelative: Bool) async {
        loadError = nil
        let resume = recents.position(for: url).flatMap { resumeTarget(lastPosition: $0.position, duration: $0.duration) }
        // Tear down the previous session's extractor up front so a failed
        // re-open does not strand it (it would otherwise linger until the
        // engine's 10 s idle-close).
        let previousExtractor = frameExtractor
        frameExtractor = nil
        scrubPreview.reset()
        if let previousExtractor { Task { await previousExtractor.shutdown() } }
        do {
            let options = LoadOptions(audioOnly: isAudioExtension(url))
            try await engine.load(url: url, startPosition: resume, options: options)
            engine.play()
            loadedURL = url
            frameExtractor = engine.makeFrameExtractor()
            scrubPreview.configure(extractor: frameExtractor, enabled: frameExtractor != nil)
            selectedSubtitleIndex = nil
            rate = 1.0
            engine.setRate(1.0)
            if let bm = BookmarkAccess.bookmark(for: url) {
                recents.record(url: url, bookmarkData: bm, duration: duration)
            }
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            if let resume { resumeMessage = "Resuming from \(formatTimecode(resume))" }
            else { resumeMessage = nil }
        } catch {
            loadError = "Could not play \(url.lastPathComponent): \(error.localizedDescription)"
            loadedURL = nil
        }
    }

    /// Reopen a recents entry: resolve its bookmark, hold scope, then load.
    func openRecent(_ item: RecentItem) async {
        scoped?.stop()
        guard let resource = ScopedResource(bookmark: item.bookmarkData) else {
            loadError = "Could not open \(item.name): the file may have moved or been deleted."
            return
        }
        scoped = resource
        await openInternal(url: resource.url, recordPlaylistRelative: true)
    }

    func startOver() {
        resumeMessage = nil
        seek(to: 0)
    }

    func dismissResumeMessage() { resumeMessage = nil }

    func togglePlayPause() {
        switch state {
        case .playing:
            flushPosition()
            engine.pause()
        case .paused: engine.play()
        default: break
        }
    }

    /// Replay from the beginning. Used when the video has reached its end.
    /// Resets the speed to 1x so the rate menu and actual playback agree
    /// (the engine's play() drops back to 1x on replay).
    func restart() {
        Task {
            await engine.seek(to: 0)
            engine.play()
            setRate(1.0)
        }
    }

    /// The transport's primary action: replay if the video has ended,
    /// otherwise toggle play/pause. Backs the play button, the video tap,
    /// and the Space key so all three stay consistent at end-of-stream.
    func primaryAction() {
        if isEnded { restart() } else { togglePlayPause() }
    }

    func stop() {
        flushPosition()
        engine.stop()
        let extractorToClose = frameExtractor
        frameExtractor = nil
        scrubPreview.reset()
        if let extractorToClose { Task { await extractorToClose.shutdown() } }
        scoped?.stop(); scoped = nil
        folderScoped?.stop(); folderScoped = nil
        playlist = nil
        loadedURL = nil
        loadError = nil
        resumeMessage = nil
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

    // MARK: - Snapshot

    /// Capture the current frame at full resolution. Nil when nothing is
    /// loaded. Uses the session extractor's frame-accurate path.
    func snapshotCurrentFrame() async -> CGImage? {
        guard let frameExtractor else { return nil }
        return await frameExtractor.snapshot(at: currentTime)
    }

    // MARK: - Folder / Playlist

    /// Open a folder: list playable files, sort, and play the first.
    func openFolder(_ folderURL: URL, bookmarkData: Data? = nil) async {
        folderScoped?.stop(); folderScoped = nil
        if let data = bookmarkData, let res = ScopedResource(bookmark: data) {
            folderScoped = res
        }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil)) ?? []
        let files = playableFiles(in: contents)
        guard !files.isEmpty else {
            loadError = "No playable files in \(folderURL.lastPathComponent)."
            return
        }
        playlist = Playlist(items: files, currentIndex: 0)
        await openInternal(url: files[0], recordPlaylistRelative: false)
    }

    /// Build a folder playlist around an already-open single file, given access
    /// to its parent folder (from a one-time prompt). Keeps the current file playing.
    func adoptFolderPlaylist(folderURL: URL, around currentURL: URL, bookmarkData: Data?) {
        folderScoped?.stop(); folderScoped = nil
        if let data = bookmarkData, let res = ScopedResource(bookmark: data) { folderScoped = res }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil)) ?? []
        let files = playableFiles(in: contents)
        let index = files.firstIndex { $0.standardizedFileURL == currentURL.standardizedFileURL } ?? 0
        playlist = files.isEmpty ? nil : Playlist(items: files, currentIndex: index)
    }

    func playNext() async {
        flushPosition()
        guard var pl = playlist, let url = pl.next() else { return }
        playlist = pl
        await openInternal(url: url, recordPlaylistRelative: false)
    }

    func playPrevious() async {
        flushPosition()
        guard var pl = playlist, let url = pl.previous() else { return }
        playlist = pl
        await openInternal(url: url, recordPlaylistRelative: false)
    }

    // MARK: - Speed

    /// Available playback speeds offered in the UI.
    static let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    func setRate(_ newRate: Float) {
        engine.setRate(newRate)
        rate = newRate
    }

    // MARK: - Volume

    func adjustVolume(by delta: Float) {
        if isMuted { preMuteVolume = nil }   // an explicit change cancels mute memory
        volume = volume + delta
    }

    func toggleMute() {
        if isMuted {
            volume = preMuteVolume ?? 1.0
            preMuteVolume = nil
        } else {
            preMuteVolume = volume
            volume = 0
        }
    }

    // MARK: - Errors

    func clearLoadError() {
        loadError = nil
    }

    // MARK: - Position persistence

    private func persistPositionThrottled() {
        guard let url = loadedURL, state == .playing else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPersist) >= 5 else { return }
        lastPersist = now
        recents.updatePosition(currentTime, duration: duration, for: url)
    }

    /// Force-save the current position (call on pause, stop, window close).
    func flushPosition() {
        guard let url = loadedURL, currentTime > 0,
              !isEffectivelyFinished(position: currentTime, duration: duration) else { return }
        recents.updatePosition(currentTime, duration: duration, for: url)
    }

    // MARK: - Sleep prevention

    /// Disables idle display/system sleep while playing so the screen does
    /// not dim mid-video; releases the assertion the moment playback stops.
    private func updateSleepAssertion() {
        if state == .playing {
            if sleepAssertion == nil {
                // Video keeps the display awake; audio only blocks system
                // sleep so the screen may dim while music plays.
                let options: ProcessInfo.ActivityOptions = backend == .audio
                    ? [.idleSystemSleepDisabled]
                    : [.idleDisplaySleepDisabled, .idleSystemSleepDisabled]
                sleepAssertion = ProcessInfo.processInfo.beginActivity(
                    options: options, reason: "Media playback")
            }
        } else if let token = sleepAssertion {
            ProcessInfo.processInfo.endActivity(token)
            sleepAssertion = nil
        }
    }
}
