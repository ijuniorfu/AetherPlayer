import AetherEngine
import AVKit
import Combine

@MainActor
final class PlayerHostController: AVPlayerViewController {
    let model: PlayerViewModel
    private var cancellables = Set<AnyCancellable>()
    /// True while a PiP handoff is dismissing the VC, so viewWillDisappear
    /// does not tear playback down. Set synchronously in the PiP delegate.
    nonisolated(unsafe) var pipActive = false
    private let aetherView = AetherPlayerView()
    private var aetherMounted = false

    init(model: PlayerViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Keep AVKit's Now Playing / AirPods backend; Plan 1 shows its default chrome.
        showsPlaybackControls = true
        allowsPictureInPicturePlayback = true
        canStartPictureInPictureAutomaticallyFromInline = true
        videoGravity = .resizeAspect
        delegate = self
        model.engine.backgroundPlaybackEnabled = true
        bindEngine()
    }

    private func bindEngine() {
        // Native path (HEVC/H.264/HW-AV1): AVKit renders engine.currentAVPlayer.
        model.engine.$currentAVPlayer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] avPlayer in
                guard let self else { return }
                self.player = avPlayer
                if let avPlayer {
                    avPlayer.allowsExternalPlayback = true
                    avPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
                    // A new load's player is ready; stage Now Playing even if this
                    // file carries no container metadata (falls back to filename).
                    self.stageNowPlaying()
                }
            }
            .store(in: &cancellables)

        // Stage Now Playing via externalMetadata whenever the engine resolves media
        // metadata; the engine replays it across audio-switch reloads. We never touch
        // MPNowPlayingInfoCenter directly, AVKit owns Now Playing on iOS.
        model.engine.$metadata
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.stageNowPlaying() }
            .store(in: &cancellables)

        // Software-decode path (dav1d AV1, VP9): AetherPlayerView renders into
        // AVKit's content overlay. Also mounted for the legacy `.aether` case.
        model.engine.$playbackBackend
            .receive(on: DispatchQueue.main)
            .sink { [weak self] backend in
                guard let self else { return }
                switch backend {
                case .software, .aether: self.mountAetherIfNeeded()
                case .native, .none, .audio: self.unmountAether()
                }
            }
            .store(in: &cancellables)
    }

    private func mountAetherIfNeeded() {
        guard !aetherMounted, let overlay = contentOverlayView else { return }
        aetherView.translatesAutoresizingMaskIntoConstraints = false
        overlay.insertSubview(aetherView, at: 0)
        NSLayoutConstraint.activate([
            aetherView.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            aetherView.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            aetherView.topAnchor.constraint(equalTo: overlay.topAnchor),
            aetherView.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
        ])
        model.engine.bind(view: aetherView)
        aetherMounted = true
    }

    private func unmountAether() {
        guard aetherMounted else { return }
        model.engine.unbind(view: aetherView)
        aetherView.removeFromSuperview()
        aetherMounted = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard !pipActive else { return }   // PiP handoff, keep playing
        model.stop()
    }

    /// Idempotent: safe to call from both the metadata sink and the currentAVPlayer
    /// sink. Title-only for v1; artwork enrichment is a later refinement.
    private func stageNowPlaying() {
        guard let url = model.loadedURL else { return }
        let title = model.metadata?.title ?? url.deletingPathExtension().lastPathComponent
        model.engine.setExternalMetadata(NowPlayingMetadata.items(title: title, artwork: nil))
    }
}
