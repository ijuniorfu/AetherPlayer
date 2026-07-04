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
    private(set) var activeSubtitleTrackIndex: Int?
    private(set) var metadata: MediaMetadata?
    // Disc titles + chapters (#67); empty for non-disc sources.
    private(set) var discTitles: [TitleInfo] = []
    private(set) var selectedDiscTitleID: Int?
    private(set) var discChapters: [ChapterInfo] = []

    // Host-only state.
    private(set) var loadedURL: URL?
    private(set) var loadError: String?

    private(set) var playlist: Playlist?
    private var folderScoped: ScopedResource?
    var hasNext: Bool { playlist?.hasNext ?? false }
    var hasPrevious: Bool { playlist?.hasPrevious ?? false }

    /// Repeat behavior for audio playback (off / repeat-all / repeat-one),
    /// cycled from the transport bar. Persisted across launches.
    private(set) var repeatMode: RepeatMode = .off

    /// Advance the repeat mode through its off -> all -> one -> off cycle.
    func cycleRepeatMode() {
        repeatMode = repeatMode.cycled
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "player.repeatMode")
    }

    /// Whether folder playback is shuffled. Persisted across launches and
    /// applied to the active folder playlist immediately when toggled.
    private(set) var shuffleEnabled: Bool = false

    func toggleShuffle() {
        shuffleEnabled.toggle()
        UserDefaults.standard.set(shuffleEnabled, forKey: "player.shuffle")
        playlist?.setShuffled(shuffleEnabled)
    }

    /// User subtitle size choice, combined with the surface-relative auto
    /// scale in `SubtitleOverlayView`. Persisted across launches.
    private(set) var subtitleSize: SubtitleSize = .normal

    func setSubtitleSize(_ size: SubtitleSize) {
        subtitleSize = size
        UserDefaults.standard.set(size.rawValue, forKey: "player.subtitleSize")
    }

    let recents = RecentsStore()
    private let nowPlaying = NowPlayingController()
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
        if let raw = UserDefaults.standard.string(forKey: "player.repeatMode"),
           let mode = RepeatMode(rawValue: raw) {
            repeatMode = mode
        }
        shuffleEnabled = UserDefaults.standard.bool(forKey: "player.shuffle")
        if let raw = UserDefaults.standard.string(forKey: "player.subtitleSize"),
           let size = SubtitleSize(rawValue: raw) {
            subtitleSize = size
        }
        nowPlaying.configure(actions: .init(
            play: { [weak self] in self?.engine.play() },
            pause: { [weak self] in self?.engine.pause() },
            toggle: { [weak self] in self?.primaryAction() },
            skip: { [weak self] d in self?.seek(by: d) },
            next: { [weak self] in Task { await self?.playNext() } },
            previous: { [weak self] in Task { await self?.playPrevious() } },
            seekTo: { [weak self] t in self?.seek(to: t) }
        ))
    }

    private func bind() {
        engine.$state.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.state = $0
            self?.updateSleepAssertion()
            if $0 == .idle, self?.hasMedia == true {
                self?.handleTrackEnded()
            }
            self?.pushNowPlaying()
        }.store(in: &cancellables)
        // The playback clock lives on engine.clock (a separate
        // ObservableObject since AetherEngine#29) so its ~10 Hz ticks
        // only reach views that explicitly observe the clock.
        engine.clock.$currentTime.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.currentTime = $0
            self?.persistPositionThrottled()
            self?.pushNowPlayingThrottled()
        }.store(in: &cancellables)
        engine.$duration.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.duration = $0
            self?.pushNowPlaying()
        }.store(in: &cancellables)
        engine.$audioTracks.receive(on: DispatchQueue.main).sink { [weak self] in self?.audioTracks = $0 }.store(in: &cancellables)
        engine.$subtitleTracks.receive(on: DispatchQueue.main).sink { [weak self] in self?.subtitleTracks = $0 }.store(in: &cancellables)
        engine.$activeAudioTrackIndex.receive(on: DispatchQueue.main).sink { [weak self] in self?.activeAudioTrackIndex = $0 }.store(in: &cancellables)
        engine.$discTitles.receive(on: DispatchQueue.main).sink { [weak self] in self?.discTitles = $0 }.store(in: &cancellables)
        engine.$selectedDiscTitle.receive(on: DispatchQueue.main).sink { [weak self] in self?.selectedDiscTitleID = $0?.id }.store(in: &cancellables)
        engine.$discChapters.receive(on: DispatchQueue.main).sink { [weak self] in self?.discChapters = $0 }.store(in: &cancellables)
        engine.$playbackBackend.receive(on: DispatchQueue.main).sink { [weak self] in self?.backend = $0 }.store(in: &cancellables)
        engine.$subtitleCues.receive(on: DispatchQueue.main).sink { [weak self] in self?.subtitleCues = $0 }.store(in: &cancellables)
        engine.$isSubtitleActive.receive(on: DispatchQueue.main).sink { [weak self] in self?.isSubtitleActive = $0 }.store(in: &cancellables)
        engine.$activeSubtitleTrackIndex.receive(on: DispatchQueue.main).sink { [weak self] in self?.activeSubtitleTrackIndex = $0 }.store(in: &cancellables)
        engine.$metadata.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.metadata = $0
            self?.pushNowPlaying()
        }.store(in: &cancellables)
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
            let options = LoadOptions(audioOnly: isAudioExtension(url), preferredAudioLanguages:["en", "eng"], preferredSubtitleLanguages: ["ch", "chi", "zh", "zho"])
            try await engine.load(url: url, startPosition: resume, options: options)
            engine.play()
            loadedURL = url
            frameExtractor = engine.makeFrameExtractor()
            scrubPreview.configure(extractor: frameExtractor, enabled: frameExtractor != nil)
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
        nowPlaying.clear()
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

    func selectTitle(id: Int) {
        engine.selectTitle(id: id)
    }

    func selectChapter(id: Int) {
        engine.selectChapter(id: id)
    }

    func selectSubtitle(engineIndex: Int) {
        engine.selectSubtitleTrack(index: engineIndex)
    }

    func disableSubtitle() {
        engine.clearSubtitle()
    }

    func loadSidecarSubtitle(url: URL) {
        let track = engine.addExternalSubtitleTrack(
            ExternalSubtitleTrack(url: url, name: "English", language: "en"))
        engine.selectSubtitleTrack(index: track.id)
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
        let pl = Playlist(items: files, currentIndex: 0, isShuffled: shuffleEnabled)
        playlist = pl
        await openInternal(url: pl.current ?? files[0], recordPlaylistRelative: false)
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
        playlist = files.isEmpty ? nil
            : Playlist(items: files, currentIndex: index, isShuffled: shuffleEnabled)
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

    /// Restart the folder playlist from its first track (repeat-all wrap).
    private func playPlaylistFirst() async {
        flushPosition()
        guard var pl = playlist, let url = pl.rewindToStart() else { return }
        playlist = pl
        await openInternal(url: url, recordPlaylistRelative: false)
    }

    /// Decide what happens when the current item reaches its natural end.
    /// Repeat behavior applies to audio only; video keeps the plain
    /// auto-advance-within-a-folder behavior.
    private func handleTrackEnded() {
        guard let url = loadedURL else { return }
        recents.markFinished(url)

        guard backend == .audio else {
            if playlist?.hasNext == true { Task { await playNext() } }
            return
        }

        switch repeatMode {
        case .one:
            restart()                                   // loop this track
        case .all:
            if playlist?.hasNext == true { Task { await playNext() } }
            else if playlist != nil { Task { await playPlaylistFirst() } }  // wrap
            else { restart() }                          // single file: loop it
        case .off:
            if playlist?.hasNext == true { Task { await playNext() } }
        }
    }

    // MARK: - Speed

    /// Available playback speeds offered in the UI.
    static let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    func setRate(_ newRate: Float) {
        engine.setRate(newRate)
        rate = newRate
        pushNowPlaying()
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

    // MARK: - Now Playing

    private func pushNowPlaying() {
        guard hasMedia else { nowPlaying.clear(); return }
        nowPlaying.update(
            metadata: metadata,
            fallbackTitle: loadedURL.map { $0.deletingPathExtension().lastPathComponent } ?? "AetherPlayer",
            duration: duration,
            elapsed: currentTime,
            rate: isPlaying ? rate : 0)
        nowPlaying.updateAvailability(hasNext: hasNext, hasPrevious: hasPrevious)
    }

    private var lastNowPlayingPush: Date = .distantPast
    /// Throttled variant for the per-tick currentTime updates (at most ~1/s)
    /// so we do not rewrite MPNowPlayingInfoCenter on every playhead change.
    private func pushNowPlayingThrottled() {
        let now = Date()
        guard now.timeIntervalSince(lastNowPlayingPush) >= 1 else { return }
        lastNowPlayingPush = now
        pushNowPlaying()
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
