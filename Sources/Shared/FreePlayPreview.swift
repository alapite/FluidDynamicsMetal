import AVFoundation

/// Plays the bundled demonstration independently of the live Metal simulation.
@MainActor
final class FreePlayPreviewPlayback {
    static let instruction = "Drag to stir"
    private static var hasPresented = false

    static func claimLaunchPreview() -> Bool {
        guard !hasPresented else { return false }
        hasPresented = true
        return true
    }

    let layer = AVPlayerLayer()
    private var player: AVPlayer?
    private var observers: [NSObjectProtocol] = []
    private var statusObservation: NSKeyValueObservation?
    private(set) var showsStill = false
    var didShowStill: (() -> Void)?

    init(reduceMotion: Bool) {
        layer.videoGravity = .resizeAspect
        guard !reduceMotion, let url = Bundle.main.url(forResource: "FreePlayPreview", withExtension: "mp4") else {
            showsStill = true
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        self.player = player
        layer.player = player

        for event in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: event, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.showStill() }
            })
        }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.player?.currentItem?.status == .failed else { return }
                self.showStill()
            }
        }
    }

    func setActive(_ active: Bool) {
        if active { player?.play() }
        else { player?.pause() }
    }

    func showStill() {
        guard !showsStill else { return }
        showsStill = true
        stop()
        didShowStill?()
    }

    func stop() {
        player?.pause()
        layer.player = nil
        player = nil
        statusObservation?.invalidate()
        statusObservation = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    isolated deinit {
        stop()
    }

    static func usesStill(reduceMotion: Bool) -> Bool {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--free-play-preview-reduce-motion") { return true }
#endif
        return reduceMotion
    }
}

extension SimulationMode {
    var thumbnailName: String {
        switch self {
        case .freePlay: return "ExperimentFreePlay"
        case .experiment(.advection): return "ExperimentAdvection"
        case .experiment(.interactingVortices): return "ExperimentVortices"
        case .experiment(.dyeStretching): return "ExperimentStretching"
        case .dyeAdvection3D: return "ExperimentDye3D"
        }
    }
}

#if os(macOS)
import AppKit

@MainActor
final class FreePlayPreviewView: NSView {
    let playback: FreePlayPreviewPlayback
    private let still = NSImageView(image: NSImage(named: "FreePlayPreviewStill") ?? NSImage())

    init(reduceMotion: Bool) {
        playback = FreePlayPreviewPlayback(reduceMotion: reduceMotion)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        still.imageScaling = .scaleProportionallyUpOrDown
        still.frame = bounds
        still.autoresizingMask = [.width, .height]
        still.isHidden = !playback.showsStill
        addSubview(still)

        let videoSurface = NSView(frame: bounds)
        videoSurface.wantsLayer = true
        videoSurface.autoresizingMask = [.width, .height]
        videoSurface.layer?.addSublayer(playback.layer)
        addSubview(videoSurface)

        let instruction = NSTextField(labelWithString: FreePlayPreviewPlayback.instruction)
        instruction.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        instruction.textColor = .white
        instruction.drawsBackground = true
        instruction.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        instruction.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instruction)
        NSLayoutConstraint.activate([
            instruction.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            instruction.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])

        for view in [self, still, videoSurface, instruction] { view.setAccessibilityElement(false) }
        playback.didShowStill = { [weak self] in self?.still.isHidden = false }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playback.layer.frame = bounds
        CATransaction.commit()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

#else
import UIKit

@MainActor
final class FreePlayPreviewView: UIView {
    let playback: FreePlayPreviewPlayback
    var artworkAvailableFrame: CGRect = .zero {
        didSet { if oldValue != artworkAvailableFrame { setNeedsLayout() } }
    }
    private let artwork = UIView()
    private let instruction = UILabel()
    private let still = UIImageView(image: UIImage(named: "FreePlayPreviewStill"))

    init(reduceMotion: Bool) {
        playback = FreePlayPreviewPlayback(reduceMotion: reduceMotion)
        super.init(frame: .zero)
        backgroundColor = .black
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true

        still.contentMode = .scaleAspectFit
        still.frame = artwork.bounds
        still.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        still.isHidden = !playback.showsStill
        addSubview(artwork)
        artwork.addSubview(still)

        let videoSurface = UIView(frame: artwork.bounds)
        videoSurface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoSurface.layer.addSublayer(playback.layer)
        artwork.addSubview(videoSurface)

        instruction.text = FreePlayPreviewPlayback.instruction
        instruction.font = UIFont.preferredFont(forTextStyle: .headline)
        instruction.adjustsFontForContentSizeCategory = true
        instruction.numberOfLines = 0
        instruction.textColor = .white
        instruction.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        instruction.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instruction)
        NSLayoutConstraint.activate([
            instruction.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            instruction.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            instruction.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16)
        ])

        playback.didShowStill = { [weak self] in self?.still.isHidden = false }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Reserve the visible canvas above the HUD in portrait and beside it
        // in landscape so the demonstration is visible before the first touch.
        let top = max(artworkAvailableFrame.minY, instruction.frame.maxY + 12)
        artwork.frame = CGRect(x: artworkAvailableFrame.minX, y: top, width: artworkAvailableFrame.width,
                               height: max(0, artworkAvailableFrame.maxY - top))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playback.layer.frame = artwork.bounds
        CATransaction.commit()
    }
}
#endif
