import SwiftUI
import AppKit

/// One player window: its own view model and engine, so two windows play side by side without sharing
/// a clock, a track selection or a speed. Closing the window ends the session (AetherPlayer#11).
@Observable
@MainActor
final class PlayerSession {
    let model: PlayerViewModel
    @ObservationIgnored private(set) weak var window: NSWindow?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    var showOpenURLSheet = false
    var alwaysOnTop = false {
        didSet { window?.level = alwaysOnTop ? .floating : .normal }
    }

    init(model: PlayerViewModel) {
        self.model = model
    }

    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        observers.forEach(NotificationCenter.default.removeObserver)
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.becameKey() }
            },
            center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            },
        ]
        // Only one window can hold the autosave name; the others cascade from it.
        window.setFrameAutosaveName("AetherPlayerMainWindow")
        window.level = alwaysOnTop ? .floating : .normal
        if window.isKeyWindow { becameKey() }
    }

    private func becameKey() {
        PlayerWindowRegistry.shared.activate(self)
        model.claimNowPlaying()
    }

    private func close() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        model.stop()
        PlayerWindowRegistry.shared.unregister(self)
    }
}

/// The open player windows and the one the menu bar, the Stats window and Finder's "Open With" act on:
/// the player window that was key last. Tracked by hand rather than through focused values so the
/// menus keep their target while the Stats or Settings window has focus.
@Observable
@MainActor
final class PlayerWindowRegistry {
    static let shared = PlayerWindowRegistry()

    private(set) var sessions: [PlayerSession] = []
    private(set) var active: PlayerSession?
    /// Set by the first player window; opens another one from places without a SwiftUI environment.
    @ObservationIgnored var openWindow: OpenWindowAction?
    /// Work for a window that has been asked for but not registered yet (Finder open with no window).
    @ObservationIgnored private var pending: [(PlayerSession) -> Void] = []

    func register(_ session: PlayerSession) {
        sessions.append(session)
        if active == nil { active = session }
        let work = pending
        pending = []
        work.forEach { $0(session) }
    }

    func unregister(_ session: PlayerSession) {
        sessions.removeAll { $0 === session }
        if active === session { active = sessions.last }
    }

    func activate(_ session: PlayerSession) {
        guard sessions.contains(where: { $0 === session }) else { return }
        active = session
    }

    /// Runs `work` against the active window, or against a new one when every player window is closed.
    func withActiveSession(_ work: @escaping (PlayerSession) -> Void) {
        if let active {
            work(active)
            bringToFront(active)
        } else {
            pending.append(work)
            openPlayerWindow()
        }
    }

    func openPlayerWindow() {
        openWindow?(id: PlayerWindowID.value)
        NSApp.activate(ignoringOtherApps: true)
    }

    func bringToFront(_ session: PlayerSession? = nil) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            (session ?? self.active)?.window?.makeKeyAndOrderFront(nil)
        }
    }
}

enum PlayerWindowID {
    static let value = "player"
}

/// Weak handle to the hosting window, so view state never keeps a closed window alive.
struct WindowRef: Equatable {
    weak var window: NSWindow?
    static func == (lhs: WindowRef, rhs: WindowRef) -> Bool { lhs.window === rhs.window }
}

extension EnvironmentValues {
    /// The player window a view lives in. Window actions (full screen, title, cursor) go to this one,
    /// not to `NSApp.keyWindow`, which is another window whenever a player in the background updates.
    @Entry var playerWindow: NSWindow? = nil
}

/// Reports the NSWindow hosting it.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> _View {
        let v = _View(); v.onWindow = onWindow; return v
    }
    func updateNSView(_ nsView: _View, context: Context) { nsView.onWindow = onWindow }

    final class _View: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}

/// Root of one player window. The session is built on appear rather than in an initializer, because
/// SwiftUI may construct this struct more than once, and each construction would start an engine.
struct PlayerWindowView: View {
    @State private var session: PlayerSession?
    @State private var engineFailed = false
    @State private var windowRef = WindowRef()
    /// A Finder open that reached this window before its session existed (cold launch).
    @State private var pendingURL: URL?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if let session {
                ContentView(model: session.model) {
                    session.showOpenURLSheet = true
                }
                .sheet(isPresented: Bindable(session).showOpenURLSheet) {
                    OpenURLSheet(model: session.model)
                }
                .environment(\.playerWindow, windowRef.window)
            } else if engineFailed {
                Text("AetherEngine failed to initialize.")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                Color.black
            }
        }
        .background(WindowAccessor { window in windowRef = WindowRef(window: window) })
        // Finder opens land in an open player window. Without this the WindowGroup answers every
        // opened file with a fresh, empty window of its own.
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .onOpenURL { url in
            if let session {
                Task { await session.model.open(url: url) }
                PlayerWindowRegistry.shared.bringToFront(session)
            } else {
                pendingURL = url
            }
        }
        .onAppear {
            PlayerWindowRegistry.shared.openWindow = openWindow
            guard session == nil, !engineFailed else { return }
            do {
                let session = PlayerSession(model: try PlayerViewModel())
                self.session = session
                if let window = windowRef.window { session.attach(window) }
                PlayerWindowRegistry.shared.register(session)
                if let url = pendingURL {
                    pendingURL = nil
                    Task { await session.model.open(url: url) }
                }
            } catch {
                engineFailed = true
            }
        }
        .onChange(of: windowRef) { _, ref in
            if let window = ref.window { session?.attach(window) }
        }
        .frame(minWidth: 640, minHeight: 360)
    }
}
