import SwiftUI
import SceneKit
import UIKit

struct GameSceneView: UIViewRepresentable {
    let game: GameController

    func makeCoordinator() -> Coordinator { Coordinator(game) }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: .zero, options: nil)
        game.attach(v)
        let c = context.coordinator

        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.tap(_:)))
        let pan1 = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.pan1(_:)))
        pan1.maximumNumberOfTouches = 1
        let pan2 = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.pan2(_:)))
        pan2.minimumNumberOfTouches = 2
        pan2.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.pinch(_:)))
        let rotate = UIRotationGestureRecognizer(target: c, action: #selector(Coordinator.rotate(_:)))
        for g in [tap, pan1, pan2, pinch, rotate] as [UIGestureRecognizer] {
            g.delegate = c
            v.addGestureRecognizer(g)
        }
        c.singlePan = pan1
        c.multi = [pan2, pinch, rotate]
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let game: GameController
        weak var singlePan: UIPanGestureRecognizer?
        var multi: [UIGestureRecognizer] = []
        private var lastPan2: CGPoint?
        private var multiActive = 0

        init(_ g: GameController) { game = g }

        @objc func tap(_ g: UITapGestureRecognizer) {
            game.handleTap(g.location(in: g.view))
        }

        @objc func pan1(_ g: UIPanGestureRecognizer) {
            let p = g.location(in: g.view)
            switch g.state {
            case .began:
                let t = g.translation(in: g.view)
                game.dragBegan(start: CGPoint(x: p.x - t.x, y: p.y - t.y), current: p)
            case .changed:
                game.dragChanged(p)
            default:
                game.dragEnded()
            }
        }

        private func beginMulti() {
            if multiActive == 0, let p = singlePan, p.state == .began || p.state == .changed {
                p.isEnabled = false
                p.isEnabled = true
                game.dragEnded()
            }
            multiActive += 1
        }

        private func endMulti() {
            multiActive = max(0, multiActive - 1)
        }

        @objc func pan2(_ g: UIPanGestureRecognizer) {
            let p = g.location(in: g.view)
            switch g.state {
            case .began:
                beginMulti()
                lastPan2 = p
            case .changed:
                if g.numberOfTouches < 2 {
                    lastPan2 = nil
                    return
                }
                if let last = lastPan2 { game.cameraPan(from: last, to: p) }
                lastPan2 = p
            default:
                lastPan2 = nil
                endMulti()
            }
        }

        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            switch g.state {
            case .began:
                beginMulti()
            case .changed:
                game.cameraZoom(g.scale, around: g.location(in: g.view))
                g.scale = 1
            default:
                endMulti()
            }
        }

        @objc func rotate(_ g: UIRotationGestureRecognizer) {
            switch g.state {
            case .began:
                beginMulti()
            case .changed:
                game.cameraRotate(g.rotation)
                g.rotation = 0
            default:
                endMulti()
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            multi.contains(g) && multi.contains(other)
        }
    }
}
