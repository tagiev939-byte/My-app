import AVFoundation
import UIKit

enum SFX: String, CaseIterable {
    case tap, place, belt, coin, upgrade, goal, demolish, land, error, contract, boost
}

final class Sound {
    static let shared = Sound()
    var enabled = true
    private var players: [SFX: [AVAudioPlayer]] = [:]
    private var next: [SFX: Int] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for s in SFX.allCases {
            guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "wav") else { continue }
            let n = (s == .coin || s == .belt || s == .place || s == .tap) ? 4 : 2
            var list: [AVAudioPlayer] = []
            for _ in 0..<n {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    list.append(p)
                }
            }
            players[s] = list
        }
    }

    private var music: AVAudioPlayer?

    func setMusic(_ on: Bool) {
        if on {
            if AVAudioSession.sharedInstance().isOtherAudioPlaying { return }
            if music == nil, let url = Bundle.main.url(forResource: "music", withExtension: "wav"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.numberOfLoops = -1
                p.volume = 0
                p.prepareToPlay()
                music = p
            }
            guard let m = music, !m.isPlaying else { return }
            m.volume = 0
            m.play()
            m.setVolume(0.3, fadeDuration: 2.5)
        } else {
            music?.setVolume(0, fadeDuration: 0.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                if self?.music?.volume == 0 { self?.music?.pause() }
            }
        }
    }

    func play(_ s: SFX, volume: Float = 1) {
        guard enabled, let list = players[s], !list.isEmpty else { return }
        let i = next[s, default: 0] % list.count
        next[s] = i + 1
        let p = list[i]
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}

enum Haptics {
    static var enabled = true

    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func soft(_ intensity: CGFloat = 0.5) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: intensity)
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
