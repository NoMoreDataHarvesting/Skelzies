import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    weak var vm: GameViewModel?

    private enum TurnState { case idle, aiming, rolling }
    private var turnState: TurnState = .idle
    private var activeID = 0

    private var caps: [Int: SKSpriteNode] = [:]

    // Aiming
    private var aimTouch: UITouch?
    private var aimDir = CGVector(dx: 0, dy: 1)
    private var dragValid = false
    private var aimStartTime: TimeInterval = 0
    private var sceneTime: TimeInterval = 0

    // Shot tracking
    private var victims: Set<Int> = []
    private var offWorldShooter = false
    private var settleFrames = 0
    private var rollStartTime: TimeInterval = 0

    // Aim visuals
    private let aimLine = SKShapeNode()
    private let aimHead = SKShapeNode()
    private let powerRing = SKShapeNode()

    // Tuning
    private let pulsePeriod: TimeInterval = 2.4    // breathing pace — slower = easier to time
    private let minSpeed: CGFloat = 90             // true tap shots for positional play
    private let maxSpeed: CGFloat = 1250
    private let maxWander: CGFloat = 0.14          // ~8° of drift at full power
    private let powerEasing: CGFloat = 1.4         // stretches the low-power band across more time
    private let rollingFriction: CGFloat = 55      // pts/s² constant decel — asphalt grip
    private let stopSpeed: CGFloat = 12            // caps grab instead of creeping

    // Ghost caps: players who haven't taken their first shot yet
    private var ghosts: Set<Int> = []

    // Per-shot randomized sway pattern
    private var wanderF1: Double = 2.8
    private var wanderF2: Double = 6.0
    private var wanderP1: Double = 0
    private var wanderP2: Double = 0
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(rgb: 0x1D1E22)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        let bg = SKSpriteNode(texture: ChalkRenderer.boardTexture())
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.size = size
        bg.zPosition = 0
        addChild(bg)

        for shape in [aimLine, aimHead, powerRing] {
            shape.zPosition = 30
            shape.lineCap = .round
            shape.lineJoin = .round
            addChild(shape)
        }
        aimLine.lineWidth = 3.5
        aimHead.lineWidth = 3.5
        powerRing.lineWidth = 4
        powerRing.strokeColor = UIColor(rgb: 0xF4D364)

        makeCaps()
        if let vm { beginTurn(for: vm.currentIndex) }
    }

    private func makeCaps() {
        guard let vm else { return }
        for player in vm.players {
            let node = SKSpriteNode(texture: ChalkRenderer.capTexture(colorIndex: player.colorIndex,
                                                                      weight: player.weight))
            node.size = CGSize(width: 34, height: 34)
            node.position = Layout.startScenePosition(slot: player.id)
            node.zPosition = 10

            let body = SKPhysicsBody(circleOfRadius: Layout.capRadius)
            body.linearDamping = 1.35
            body.angularDamping = 5
            body.restitution = 0.78
            body.friction = 0.2
            body.mass = player.weight.mass
            body.allowsRotation = false
            // Ghost until this player takes their first shot: no collisions, no contacts.
            body.categoryBitMask = 2
            body.collisionBitMask = 0
            body.contactTestBitMask = 0
            body.usesPreciseCollisionDetection = true
            node.physicsBody = body
            node.alpha = 0.45
            ghosts.insert(player.id)

            addChild(node)
            caps[player.id] = node
        }
    }

    /// A ghost cap becomes real the moment its owner takes their first shot.
    private func solidify(_ id: Int) {
        guard ghosts.contains(id), let cap = caps[id], let body = cap.physicsBody else { return }
        ghosts.remove(id)
        body.categoryBitMask = 1
        body.collisionBitMask = 1
        body.contactTestBitMask = 1
        cap.run(.fadeAlpha(to: 1, duration: 0.25))
    }

    // MARK: - Turn control (called by the view model)

    func beginTurn(for id: Int) {
        activeID = id
        turnState = .aiming
        victims.removeAll()
        offWorldShooter = false
        aimTouch = nil
        dragValid = false
        hideAim()

        if let colorIndex = vm?.players[id].colorIndex {
            let hi = CapPalette.hiColor(colorIndex)
            aimLine.strokeColor = hi
            aimHead.strokeColor = hi
        }

        // Breathing pulse on the active cap — this is how you know whose turn it is.
        for (pid, node) in caps {
            node.removeAction(forKey: "breathe")
            node.setScale(1)
            if pid == id {
                let up = SKAction.scale(to: 1.15, duration: 0.7)
                up.timingMode = .easeInEaseOut
                let down = SKAction.scale(to: 1.0, duration: 0.7)
                down.timingMode = .easeInEaseOut
                node.run(.repeatForever(.sequence([up, down])), withKey: "breathe")
            }
        }
    }

    func endInput() {
        turnState = .idle
        aimTouch = nil
        hideAim()
        for node in caps.values {
            node.removeAction(forKey: "breathe")
            node.setScale(1)
        }
    }

    func markKiller(id: Int) {
        guard let cap = caps[id], cap.childNode(withName: "crown") == nil else { return }
        let crown = SKLabelNode(text: "👑")
        crown.name = "crown"
        crown.fontSize = 15
        crown.position = CGPoint(x: 0, y: 19)
        crown.zPosition = 1
        cap.addChild(crown)
    }

    func removeCap(id: Int) {
        guard let cap = caps[id] else { return }
        caps[id] = nil
        cap.physicsBody = nil
        puff(at: cap.position, count: 14)
        cap.run(.sequence([
            .group([.fadeOut(withDuration: 0.6), .scale(to: 1.6, duration: 0.6)]),
            .removeFromParent(),
        ]))
    }

    func resetCapToStart(id: Int) {
        guard let cap = caps[id] else { return }
        cap.physicsBody?.velocity = .zero
        for slot in 0..<8 {
            let p = Layout.startScenePosition(slot: slot)
            let clear = caps.allSatisfy { pid, other in
                pid == id || hypot(other.position.x - p.x, other.position.y - p.y) > Layout.capRadius * 2.4
            }
            if clear {
                cap.position = p
                puff(at: p, count: 6)
                return
            }
        }
        cap.position = Layout.startScenePosition(slot: id)
    }

    // MARK: - Touch handling (slingshot aim)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard turnState == .aiming, aimTouch == nil,
              let touch = touches.first, let cap = caps[activeID] else { return }
        let p = touch.location(in: self)
        guard hypot(p.x - cap.position.x, p.y - cap.position.y) < Layout.capRadius * 3.4 else { return }
        aimTouch = touch
        aimStartTime = sceneTime
        dragValid = false
        // Fresh sway pattern every shot — read it, don't memorize it.
        wanderF1 = Double.random(in: 2.2...3.4)
        wanderF2 = Double.random(in: 4.8...7.2)
        wanderP1 = Double.random(in: 0..<(2 * .pi))
        wanderP2 = Double.random(in: 0..<(2 * .pi))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = aimTouch, touches.contains(touch), let cap = caps[activeID] else { return }
        let p = touch.location(in: self)
        let dx = cap.position.x - p.x
        let dy = cap.position.y - p.y
        let len = hypot(dx, dy)
        if len > 14 {
            aimDir = CGVector(dx: dx / len, dy: dy / len)
            dragValid = true
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = aimTouch, touches.contains(touch) else { return }
        aimTouch = nil
        hideAim()
        guard dragValid, turnState == .aiming else { return }
        shoot()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = aimTouch, touches.contains(touch) {
            aimTouch = nil
            dragValid = false
            hideAim()
        }
    }

    // MARK: - Breathing power + wander

    /// 0 → 1 → 0 on a fixed rhythm, starting soft when the finger goes down.
    private var pulse: CGFloat {
        let t = sceneTime - aimStartTime
        return CGFloat((1 - cos(2 * Double.pi * t / pulsePeriod)) / 2)
    }

    /// The shot direction drifts — two overlapping waves, randomized per shot,
    /// biting harder as the power gauge climbs.
    private func wanderedDirection(_ p: CGFloat) -> CGVector {
        let t = sceneTime - aimStartTime
        let mix = 0.62 * sin(wanderF1 * t + wanderP1) + 0.38 * sin(wanderF2 * t + wanderP2)
        let w = CGFloat(mix) * maxWander * p * p
        let c = cos(w), s = sin(w)
        return CGVector(dx: aimDir.dx * c - aimDir.dy * s,
                        dy: aimDir.dx * s + aimDir.dy * c)
    }

    private func updateAimVisuals() {
        guard let cap = caps[activeID] else { return }
        let p = pulse
        let dir = wanderedDirection(p)
        let startR = Layout.capRadius + 8
        let len = 40 + p * 175
        let sx = cap.position.x + dir.dx * startR
        let sy = cap.position.y + dir.dy * startR
        let ex = cap.position.x + dir.dx * (startR + len)
        let ey = cap.position.y + dir.dy * (startR + len)

        let line = CGMutablePath()
        line.move(to: CGPoint(x: sx, y: sy))
        line.addLine(to: CGPoint(x: ex, y: ey))
        aimLine.path = line.copy(dashingWithPhase: 0, lengths: [9, 8])

        let ang = atan2(dir.dy, dir.dx)
        let head = CGMutablePath()
        head.move(to: CGPoint(x: ex, y: ey))
        head.addLine(to: CGPoint(x: ex - cos(ang - 0.45) * 15, y: ey - sin(ang - 0.45) * 15))
        head.move(to: CGPoint(x: ex, y: ey))
        head.addLine(to: CGPoint(x: ex - cos(ang + 0.45) * 15, y: ey - sin(ang + 0.45) * 15))
        aimHead.path = head

        let ring = CGMutablePath()
        ring.addArc(center: cap.position, radius: Layout.capRadius + 9,
                    startAngle: .pi / 2, endAngle: .pi / 2 + p * 2 * .pi, clockwise: false)
        powerRing.path = ring
    }

    private func hideAim() {
        aimLine.path = nil
        aimHead.path = nil
        powerRing.path = nil
    }

    private func shoot() {
        guard let cap = caps[activeID], let body = cap.physicsBody else { return }
        solidify(activeID)   // first shot makes the cap real
        let p = pulse
        let dir = wanderedDirection(p)
        let eased = pow(p, powerEasing)   // widens the shallow-shot band
        let weight = vm?.players[activeID].weight ?? .welterweight
        let speed = (minSpeed + eased * (maxSpeed - minSpeed)) * weight.powerFactor
        body.velocity = CGVector(dx: dir.dx * speed, dy: dir.dy * speed)

        cap.removeAction(forKey: "breathe")
        cap.setScale(1)

        turnState = .rolling
        rollStartTime = sceneTime
        settleFrames = 0
    }

    // MARK: - Contacts (killer hits)

    func didBegin(_ contact: SKPhysicsContact) {
        guard turnState == .rolling else { return }
        let a = id(of: contact.bodyA.node)
        let b = id(of: contact.bodyB.node)
        if let a, let b {
            if a == activeID { victims.insert(b) }
            else if b == activeID { victims.insert(a) }
            puff(at: contact.contactPoint, count: 6)
        }
    }

    private func id(of node: SKNode?) -> Int? {
        caps.first(where: { $0.value === node })?.key
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime > 0 ? min(currentTime - lastUpdateTime, 1.0 / 30.0) : 1.0 / 60.0
        lastUpdateTime = currentTime
        sceneTime = currentTime

        if turnState == .aiming {
            if aimTouch != nil && dragValid { updateAimVisuals() } else { hideAim() }
        }

        guard turnState == .rolling else { return }

        // Constant rolling deceleration — asphalt grabs, it doesn't glide.
        for node in caps.values {
            guard let body = node.physicsBody else { continue }
            let v = body.velocity
            let speed = hypot(v.dx, v.dy)
            guard speed > 0 else { continue }
            let slowed = max(0, speed - rollingFriction * CGFloat(dt))
            body.velocity = slowed == 0 ? .zero
                : CGVector(dx: v.dx * slowed / speed, dy: v.dy * slowed / speed)
        }

        // Pavement limit: past this, the cap flew off the block — back to Start.
        let world = CGRect(origin: .zero, size: size).insetBy(dx: -70, dy: -70)
        for (pid, node) in caps where !world.contains(node.position) {
            if pid == activeID { offWorldShooter = true }
            resetCapToStart(id: pid)
        }

        let moving = caps.values.contains { node in
            guard let v = node.physicsBody?.velocity else { return false }
            return hypot(v.dx, v.dy) > stopSpeed
        }
        if moving {
            settleFrames = 0
        } else {
            settleFrames += 1
            if settleFrames > 10 { settle(); return }
        }
        if sceneTime - rollStartTime > 8 { settle() }
    }

    private func settle() {
        guard turnState == .rolling else { return }
        turnState = .idle
        for node in caps.values { node.physicsBody?.velocity = .zero }
        guard let vm, let cap = caps[activeID] else { return }
        let report = GeometryJudge.judge(scenePosition: cap.position,
                                         victims: Array(victims),
                                         offWorld: offWorldShooter,
                                         playerID: activeID)
        vm.resolve(report)
    }

    // MARK: - Chalk dust

    private func puff(at point: CGPoint, count: Int) {
        for _ in 0..<count {
            let dust = SKShapeNode(circleOfRadius: 1.6)
            dust.fillColor = SKColor(white: 0.95, alpha: 0.8)
            dust.strokeColor = .clear
            dust.position = point
            dust.zPosition = 15
            addChild(dust)
            let a = CGFloat.random(in: 0..<(2 * .pi))
            let r = CGFloat.random(in: 6...26)
            dust.run(.sequence([
                .group([.moveBy(x: cos(a) * r, y: sin(a) * r, duration: 0.5),
                        .fadeOut(withDuration: 0.5)]),
                .removeFromParent(),
            ]))
        }
    }
}
