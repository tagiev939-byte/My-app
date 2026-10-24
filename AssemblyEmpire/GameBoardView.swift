import SwiftUI

private enum DragMode {
    case none, pan, belt, demolish, ignore
}

struct GameBoardView: View {
    @EnvironmentObject var store: GameStore

    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var panStart: CGSize = .zero
    @State private var pinchStartScale: CGFloat?
    @State private var pinchStartOffset: CGSize = .zero
    @State private var dragMode: DragMode = .none
    @State private var lastDemolish: TilePos?
    @State private var viewSize: CGSize = .zero
    @State private var didCenter = false

    static let tile: CGFloat = 46
    static let minScale: CGFloat = 0.35
    static let maxScale: CGFloat = 2.4

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    BoardRenderer.draw(ctx, size: size, world: store.world, offset: offset, scale: scale,
                                       tile: GameBoardView.tile, selected: store.selected, tool: store.tool,
                                       clock: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(pinchGesture)
            .onAppear {
                viewSize = geo.size
                if !didCenter {
                    didCenter = true
                    center(in: geo.size)
                }
            }
            .onChange(of: geo.size) { s in viewSize = s }
            .onChange(of: store.cameraToken) { _ in center(in: viewSize) }
        }
    }

    // MARK: Camera

    private func center(in size: CGSize) {
        scale = 1
        let mid = CGFloat(World.width) * GameBoardView.tile / 2
        offset = CGSize(width: size.width / 2 - mid, height: size.height / 2 - mid)
    }

    private func clamp(_ o: CGSize, scale s: CGFloat) -> CGSize {
        let mapW = CGFloat(World.width) * GameBoardView.tile * s
        let mapH = CGFloat(World.height) * GameBoardView.tile * s
        let margin: CGFloat = 160
        let minX = viewSize.width - mapW - margin
        let maxX = margin
        let minY = viewSize.height - mapH - margin
        let maxY = margin
        return CGSize(width: min(max(o.width, min(minX, maxX)), max(minX, maxX)),
                      height: min(max(o.height, min(minY, maxY)), max(minY, maxY)))
    }

    private func tileAt(_ p: CGPoint) -> TilePos {
        let wx = (p.x - offset.width) / scale
        let wy = (p.y - offset.height) / scale
        return TilePos(x: Int(floor(wx / GameBoardView.tile)), y: Int(floor(wy / GameBoardView.tile)))
    }

    // MARK: Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if dragMode == .ignore { return }
                let moved = hypot(v.translation.width, v.translation.height)
                switch dragMode {
                case .none:
                    guard moved > 10 else { return }
                    switch store.tool {
                    case .build(.belt):
                        dragMode = .belt
                        store.beginStroke(tileAt(v.startLocation))
                        store.extendStroke(tileAt(v.location))
                    case .demolish:
                        dragMode = .demolish
                        let a = tileAt(v.startLocation)
                        store.demolish(a)
                        lastDemolish = a
                    default:
                        dragMode = .pan
                        panStart = offset
                        offset = clamp(CGSize(width: panStart.width + v.translation.width,
                                              height: panStart.height + v.translation.height), scale: scale)
                    }
                case .pan:
                    offset = clamp(CGSize(width: panStart.width + v.translation.width,
                                          height: panStart.height + v.translation.height), scale: scale)
                case .belt:
                    store.extendStroke(tileAt(v.location))
                case .demolish:
                    let t = tileAt(v.location)
                    if t != lastDemolish {
                        store.demolish(t)
                        lastDemolish = t
                    }
                case .ignore:
                    break
                }
            }
            .onEnded { v in
                if dragMode == .none && pinchStartScale == nil {
                    store.tap(tileAt(v.location))
                }
                if dragMode == .belt { store.endStroke() }
                if pinchStartScale == nil { dragMode = .none }
                lastDemolish = nil
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { m in
                if pinchStartScale == nil {
                    pinchStartScale = scale
                    pinchStartOffset = offset
                    if dragMode == .belt { store.endStroke() }
                    dragMode = .ignore
                }
                guard let s0 = pinchStartScale else { return }
                let newScale = min(max(s0 * m, GameBoardView.minScale), GameBoardView.maxScale)
                let c = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                let wx = (c.x - pinchStartOffset.width) / s0
                let wy = (c.y - pinchStartOffset.height) / s0
                scale = newScale
                offset = clamp(CGSize(width: c.x - wx * newScale, height: c.y - wy * newScale), scale: newScale)
            }
            .onEnded { _ in
                pinchStartScale = nil
                dragMode = .none
            }
    }
}

// MARK: - Renderer

enum BoardRenderer {

    static func hash(_ x: Int, _ y: Int, _ k: Int) -> CGFloat {
        var h = UInt32(truncatingIfNeeded: x &* 73856093 ^ y &* 19349663 ^ k &* 83492791)
        h ^= h >> 13
        h = h &* 0x5bd1e995
        h ^= h >> 15
        return CGFloat(h % 1000) / 1000
    }

    static func draw(_ base: GraphicsContext, size: CGSize, world: World, offset: CGSize, scale: CGFloat,
                     tile: CGFloat, selected: TilePos?, tool: Tool, clock: Double) {
        base.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.background))

        var ctx = base
        ctx.translateBy(x: offset.width, y: offset.height)
        ctx.scaleBy(x: scale, y: scale)

        let W = World.width, H = World.height
        let x0 = max(0, Int(floor(-offset.width / scale / tile)) - 1)
        let y0 = max(0, Int(floor(-offset.height / scale / tile)) - 1)
        let x1 = min(W - 1, Int(ceil((size.width - offset.width) / scale / tile)) + 1)
        let y1 = min(H - 1, Int(ceil((size.height - offset.height) / scale / tile)) + 1)
        guard x0 <= x1, y0 <= y1 else { return }

        let mapRect = CGRect(x: 0, y: 0, width: CGFloat(W) * tile, height: CGFloat(H) * tile)

        // Ground
        ctx.fill(Path(roundedRect: mapRect.insetBy(dx: -6, dy: -6), cornerRadius: 14), with: .color(Color(hex: 0x0F151E)))
        ctx.fill(Path(mapRect), with: .color(Theme.ground))
        var checker = Path()
        for y in y0...y1 {
            for x in x0...x1 where (x + y) % 2 == 0 {
                checker.addRect(CGRect(x: CGFloat(x) * tile, y: CGFloat(y) * tile, width: tile, height: tile))
            }
        }
        ctx.fill(checker, with: .color(Theme.groundAlt))

        // Resources
        let highlightOre: Bool = {
            if case .build(.miner) = tool { return true }
            return false
        }()
        let kinds: [Resource] = [.iron, .copper, .stone, .coal]
        for kind in kinds {
            var bg = Path()
            var chunks = Path()
            var any = false
            for y in y0...y1 {
                for x in x0...x1 where world.resources[y * W + x] == kind {
                    any = true
                    let r = CGRect(x: CGFloat(x) * tile, y: CGFloat(y) * tile, width: tile, height: tile)
                    bg.addRect(r)
                    for k in 0..<3 {
                        let cx = r.minX + tile * (0.18 + 0.64 * hash(x, y, k))
                        let cy = r.minY + tile * (0.18 + 0.64 * hash(x, y, k + 7))
                        let cr = tile * (0.07 + 0.07 * hash(x, y, k + 13))
                        chunks.addEllipse(in: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2))
                    }
                }
            }
            if any {
                ctx.fill(bg, with: .color(kind.color.opacity(highlightOre ? 0.42 : 0.2)))
                ctx.fill(chunks, with: .color(kind.color.opacity(0.9)))
                ctx.stroke(chunks, with: .color(.black.opacity(0.35)), lineWidth: 1)
            }
        }

        // Grid
        var grid = Path()
        for x in x0...(x1 + 1) {
            grid.move(to: CGPoint(x: CGFloat(x) * tile, y: CGFloat(y0) * tile))
            grid.addLine(to: CGPoint(x: CGFloat(x) * tile, y: CGFloat(y1 + 1) * tile))
        }
        for y in y0...(y1 + 1) {
            grid.move(to: CGPoint(x: CGFloat(x0) * tile, y: CGFloat(y) * tile))
            grid.addLine(to: CGPoint(x: CGFloat(x1 + 1) * tile, y: CGFloat(y) * tile))
        }
        ctx.stroke(grid, with: .color(.white.opacity(0.04)), lineWidth: 1 / scale)
        ctx.stroke(Path(roundedRect: mapRect.insetBy(dx: -2, dy: -2), cornerRadius: 6),
                   with: .color(Theme.border), lineWidth: 3)

        let t = world.time
        let beltPhase = t * world.beltSpeed

        // Pass 1: belts
        for y in y0...y1 {
            for x in x0...x1 {
                guard let b = world.buildings[y * W + x], b.type == .belt else { continue }
                let r = CGRect(x: CGFloat(x) * tile, y: CGFloat(y) * tile, width: tile, height: tile)
                Art.drawBelt(ctx, rect: r, dir: b.dir, phase: beltPhase)
            }
        }

        // Pass 2: buildings
        for y in y0...y1 {
            for x in x0...x1 {
                guard let b = world.buildings[y * W + x], b.type != .belt else { continue }
                let r = CGRect(x: CGFloat(x) * tile, y: CGFloat(y) * tile, width: tile, height: tile)
                let flash = max(0, 1 - (t - b.lastSaleTime) / 0.35)
                Art.drawBuilding(ctx, type: b.type, dir: b.dir, rect: r, working: b.working,
                                 progress: b.progress, time: t, recipeOutput: b.recipe?.output, flash: flash)
            }
        }

        // Pass 3: items in transit
        let itemSize = tile * 0.42
        for y in y0...y1 {
            for x in x0...x1 {
                guard let b = world.buildings[y * W + x], let item = b.item else { continue }
                let c = CGPoint(x: (CGFloat(x) + 0.5) * tile, y: (CGFloat(y) + 0.5) * tile)
                let h = tile / 2
                let entry = CGPoint(x: c.x + CGFloat(b.itemFrom.dx) * h, y: c.y + CGFloat(b.itemFrom.dy) * h)
                let p: CGPoint
                if b.type == .splitter {
                    p = Art.lerp(entry, c, CGFloat(b.itemProgress))
                } else {
                    let exit = CGPoint(x: c.x + CGFloat(b.dir.dx) * h, y: c.y + CGFloat(b.dir.dy) * h)
                    let q = CGFloat(b.itemProgress)
                    p = q < 0.5 ? Art.lerp(entry, c, q * 2) : Art.lerp(c, exit, (q - 0.5) * 2)
                }
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - itemSize * 0.5, y: p.y - itemSize * 0.35,
                                                width: itemSize, height: itemSize)),
                         with: .color(.black.opacity(0.3)))
                Art.drawItem(ctx, item, at: p, size: itemSize)
            }
        }

        // Selection
        if let s = selected {
            let r = CGRect(x: CGFloat(s.x) * tile, y: CGFloat(s.y) * tile, width: tile, height: tile).insetBy(dx: -2, dy: -2)
            let pulse = 0.6 + 0.4 * sin(clock * 5)
            ctx.stroke(Path(roundedRect: r, cornerRadius: tile * 0.22), with: .color(Theme.accent.opacity(pulse)),
                       style: StrokeStyle(lineWidth: 3, dash: [8, 5], dashPhase: CGFloat(clock * 20)))
        }

        // Floating cash
        for f in world.floats {
            let age = t - f.birth
            let a = max(0, 1 - age / 1.2)
            let p = CGPoint(x: (CGFloat(f.x) + 0.5) * tile, y: (CGFloat(f.y) + 0.1) * tile - CGFloat(age) * tile * 0.7)
            let txt = Text(f.text)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.accent.opacity(a))
            var shadowCtx = ctx
            shadowCtx.opacity = a * 0.6
            shadowCtx.draw(Text(f.text).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(.black),
                           at: CGPoint(x: p.x + 1, y: p.y + 1.5))
            ctx.draw(txt, at: p)
        }
    }
}
