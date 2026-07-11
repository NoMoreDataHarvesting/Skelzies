import CoreGraphics

/// A numbered chalk box. `rotation` is the visual rotation of its digit
/// (positive = clockwise on screen) so numbers face *outward*, like real
/// street chalk — matching the reference photo.
struct NumBox {
    let n: Int
    let rect: CGRect        // image coordinates (top-left origin)
    let rotation: CGFloat
}

/// All geometry lives in "image coordinates" (origin top-left, y down),
/// which makes CoreGraphics rendering direct. `toScene` flips into
/// SpriteKit coordinates (origin bottom-left, y up).
enum Layout {
    static let sceneSize = CGSize(width: 1200, height: 900)

    /// The chalk square. The pavement around it is in-play (no walls).
    static let boardRect = CGRect(x: 280, y: 130, width: 660, height: 660)

    static let capRadius: CGFloat = 15
    static let lineHalf: CGFloat = 2.2      // half-thickness of a chalk line

    static let cornerSize: CGFloat = 88
    static let edgeSize: CGFloat = 64

    /// "Start" cluster, outside the board's top-left corner (image coords).
    static let startImage = CGPoint(x: 190, y: 115)

    static let box13Rect: CGRect = centered(size: 96)
    static let deadFrameRect: CGRect = centered(size: 208)

    private static func centered(size s: CGFloat) -> CGRect {
        CGRect(x: boardRect.midX - s / 2, y: boardRect.midY - s / 2, width: s, height: s)
    }

    /// Layout per the reference photo:
    /// corners 1 (TL), 4 (TR), 2 (BR), 3 (BL); paired edge boxes
    /// 9|11 top, 5|7 left, 6|8 right, 12|10 bottom; 13 framed in the center.
    static let boxes: [NumBox] = {
        let b = boardRect
        let C = cornerSize, E = edgeSize, side = b.width
        func r(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) -> CGRect {
            CGRect(x: b.minX + x, y: b.minY + y, width: s, height: s)
        }
        var list: [NumBox] = []
        // Corners — digits face diagonally outward
        list.append(NumBox(n: 1, rect: r(0, 0, C),               rotation:  3 * .pi / 4))
        list.append(NumBox(n: 4, rect: r(side - C, 0, C),        rotation: -3 * .pi / 4))
        list.append(NumBox(n: 2, rect: r(side - C, side - C, C), rotation: -.pi / 4))
        list.append(NumBox(n: 3, rect: r(0, side - C, C),        rotation:  .pi / 4))
        // Top pair — upside down (read from above the board)
        list.append(NumBox(n: 9,  rect: r(side / 2 - E, 0, E), rotation: .pi))
        list.append(NumBox(n: 11, rect: r(side / 2, 0, E),     rotation: .pi))
        // Left pair — read from the left
        list.append(NumBox(n: 5, rect: r(0, side / 2 - E, E), rotation: .pi / 2))
        list.append(NumBox(n: 7, rect: r(0, side / 2, E),     rotation: .pi / 2))
        // Right pair — read from the right
        list.append(NumBox(n: 6, rect: r(side - E, side / 2 - E, E), rotation: -.pi / 2))
        list.append(NumBox(n: 8, rect: r(side - E, side / 2, E),     rotation: -.pi / 2))
        // Bottom pair — read from below
        list.append(NumBox(n: 12, rect: r(side / 2 - E, side - E, E), rotation: 0))
        list.append(NumBox(n: 10, rect: r(side / 2, side - E, E),     rotation: 0))
        // Center
        list.append(NumBox(n: 13, rect: box13Rect, rotation: 0))
        return list
    }()

    /// Every chalk segment on the board — used for the "touched a line" ruling.
    static let segments: [(CGPoint, CGPoint)] = {
        var segs: [(CGPoint, CGPoint)] = []
        func addRect(_ r: CGRect) {
            segs.append((CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY)))
            segs.append((CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY)))
            segs.append((CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)))
            segs.append((CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.minY)))
        }
        addRect(boardRect)
        for b in boxes where b.n != 13 { addRect(b.rect) }
        addRect(box13Rect)
        addRect(deadFrameRect)
        // The four diagonals: frame corners -> box-13 corners (the "tunnel")
        let f = deadFrameRect, t = box13Rect
        segs.append((CGPoint(x: f.minX, y: f.minY), CGPoint(x: t.minX, y: t.minY)))
        segs.append((CGPoint(x: f.maxX, y: f.minY), CGPoint(x: t.maxX, y: t.minY)))
        segs.append((CGPoint(x: f.maxX, y: f.maxY), CGPoint(x: t.maxX, y: t.maxY)))
        segs.append((CGPoint(x: f.minX, y: f.maxY), CGPoint(x: t.minX, y: t.maxY)))
        return segs
    }()

    // MARK: coordinate conversion

    static func toScene(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: sceneSize.height - p.y) }
    static func toImage(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: sceneSize.height - p.y) }

    /// Staggered spots around "Start" so 2–6 caps stack without overlapping.
    static let startOffsets: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 38, y: 18), CGPoint(x: -6, y: 40),
        CGPoint(x: 34, y: 54), CGPoint(x: -38, y: 22), CGPoint(x: 70, y: 40),
    ]

    static func startScenePosition(slot: Int) -> CGPoint {
        let base = toScene(startImage)
        let o = startOffsets[slot % startOffsets.count]
        return CGPoint(x: base.x + o.x, y: base.y - o.y)
    }
}

// MARK: - Geometry judge

enum GeometryJudge {

    static func judge(scenePosition: CGPoint, victims: [Int], offWorld: Bool, playerID: Int) -> ShotReport {
        let p = Layout.toImage(scenePosition)
        let clearance = Layout.capRadius + Layout.lineHalf

        // "Squarely inside": the whole cap fits inside the box, clear of chalk.
        var landed: Int?
        for b in Layout.boxes where b.rect.insetBy(dx: clearance, dy: clearance).contains(p) {
            landed = b.n
            break
        }

        var touched = false
        if landed == nil {
            for s in Layout.segments where distanceToSegment(p, s.0, s.1) <= clearance {
                touched = true
                break
            }
        }

        // Dead zone: center inside the frame around 13 without being squarely in 13.
        let dead = (landed == nil) && Layout.deadFrameRect.contains(p)

        return ShotReport(playerID: playerID,
                          victims: victims,
                          offWorld: offWorld,
                          outsideBoard: !Layout.boardRect.contains(p),
                          inDeadZone: dead,
                          landedBox: landed,
                          touchedLine: touched)
    }

    static func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let apx = p.x - a.x, apy = p.y - a.y
        let lenSq = abx * abx + aby * aby
        let t = lenSq == 0 ? 0 : max(0, min(1, (apx * abx + apy * aby) / lenSq))
        let cx = a.x + abx * t, cy = a.y + aby * t
        return hypot(p.x - cx, p.y - cy)
    }
}
