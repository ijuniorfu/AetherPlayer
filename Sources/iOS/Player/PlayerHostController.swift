import AVKit
import Combine

@MainActor
final class PlayerHostController: AVPlayerViewController {
    let model: PlayerViewModel
    private var cancellables = Set<AnyCancellable>()
    /// True while a PiP handoff is dismissing the VC, so viewWillDisappear
    /// does not tear playback down. Set synchronously in the PiP delegate.
    nonisolated(unsafe) var pipActive = false

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
                }
            }
            .store(in: &cancellables)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard !pipActive else { return }   // PiP handoff, keep playing
        model.stop()
    }
}
