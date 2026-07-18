import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    weak var vm: GameViewModel?

    private enum TurnState { case idle, aiming, rolling }
    private var turnState: TurnState = .idle
    private var activeID = 0
    private var turnToken = 0          // invalidates stale CPU shot timers

    private var caps: [Int: SKSpriteNode] = [:]

    // Aiming
    private var aimTouch: UITouch?
    private var aimAnchor = CGPoint.zero   // where the pull began (not the cap)
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

    // Tuning — base values are the V2 feel; scaled by the board unit (u) so
    // the bigger V3 board plays identically.
    private let pulsePeriod: TimeInterval = 2.4    // breathing pace — slower = easier to time
    private var u: CGFloat { Layout.unit }
    private let capDamping: CGFloat = 1.35         // exponential slide decay
    private var minSpeed: CGFloat { 90 * u }       // true tap shots for positional play
    private var maxSpeed: CGFloat { 1250 * u }
    private let maxWander: CGFloat = 0.14          // ~8° of drift at full power
    private let powerEasing: CGFloat = 1.4         // stretches the low-power band across more time
    private var rollingFriction: CGFloat { 55 * u } // pts/s² constant decel — asphalt grip
    private var stopSpeed: CGFloat { 12 * u }      // caps grab instead of creeping

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
        view.isMultipleTouchEnabled = false   // stray second touches can't steal or end the aim
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
            node.size = CGSize(width: Layout.capRadius * 2 + 4, height: Layout.capRadius * 2 + 4)
            node.position = Layout.startScenePosition(slot: player.id)
            node.zPosition = 10

            let body = SKPhysicsBody(circleOfRadius: Layout.capRadius)
            body.linearDamping = capDamping
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
        turnToken += 1
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

        scheduleCPUShotIfNeeded(for: id)
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
        crown.fontSize = 17
        crown.position = CGPoint(x: 0, y: Layout.capRadius + 5)
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
        for slot in 0..<Layout.startOffsets.count {
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
              let touch = touches.first, caps[activeID] != nil else { return }
        // CPU turns ignore human input entirely.
        if let vm, vm.players.indices.contains(activeID), vm.players[activeID].isCPU { return }
        // Anchor the pull wherever the finger lands. Edge-pinned caps stay
        // shootable because the pull-back room comes from the anchor point,
        // not from the space behind the cap.
        aimAnchor = touch.location(in: self)
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
        guard let touch = aimTouch, touches.contains(touch) else { return }
        let p = touch.location(in: self)
        let dx = aimAnchor.x - p.x
        let dy = aimAnchor.y - p.y
        let len = hypot(dx, dy)
        if len > 30 * u {   // deliberate pull — phantom-touch protection
            aimDir = CGVector(dx: dx / len, dy: dy / len)
            dragValid = true
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = aimTouch, touches.contains(touch) else { return }
        let releasePoint = touch.location(in: self)
        aimTouch = nil
        hideAim()
        guard dragValid, turnState == .aiming else { return }
        // Phantom-release protection: a real flick takes time to line up —
        // a sub-0.2s touch is a graze or capacitive dropout, not a shot.
        guard sceneTime - aimStartTime >= 0.2 else { return }
        // Returning the finger to where the pull began is a deliberate cancel.
        let pullDist = hypot(releasePoint.x - aimAnchor.x, releasePoint.y - aimAnchor.y)
        guard pullDist > 30 * u else { return }
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
        let len = (40 + p * 175) * u
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
        let p = pulse
        let dir = wanderedDirection(p)
        let eased = pow(p, powerEasing)   // widens the shallow-shot band
        let weight = vm?.players[activeID].weight ?? .welterweight
        let speed = (minSpeed + eased * (maxSpeed - minSpeed)) * weight.powerFactor
        launch(capID: activeID, direction: dir, speed: speed)
    }

    /// Shared launch path for human flicks and CPU shots.
    private func launch(capID: Int, direction: CGVector, speed: CGFloat) {
        guard let cap = caps[capID], let body = cap.physicsBody else { return }
        solidify(capID)   // first shot makes the cap real
        body.velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)

        cap.removeAction(forKey: "breathe")
        cap.setScale(1)

        turnState = .rolling
        rollStartTime = sceneTime
        settleFrames = 0
    }

    // MARK: - CPU opponents

    private func scheduleCPUShotIfNeeded(for id: Int) {
        guard let vm, vm.players.indices.contains(id),
              case .cpu(let difficulty) = vm.players[id].control else { return }
        let token = turnToken
        DispatchQueue.main.asyncAfter(deadline: .now() + difficulty.thinkTime) { [weak self] in
            guard let self, self.turnToken == token, self.turnState == .aiming else { return }
            self.performCPUShot(playerID: id, difficulty: difficulty)
        }
    }

    private func performCPUShot(playerID id: Int, difficulty: CPUDifficulty) {
        guard let vm, vm.players.indices.contains(id), let cap = caps[id] else { return }
        let me = vm.players[id]

        // Pick a target point: next box while chasing, nearest rival cap as Killer.
        let target: CGPoint
        if me.isKiller {
            let rivalCaps = vm.players
                .filter { $0.id != id && !$0.isEliminated }
                .compactMap { caps[$0.id] }
            guard let prey = rivalCaps.min(by: {
                hypot($0.position.x - cap.position.x, $0.position.y - cap.position.y) <
                hypot($1.position.x - cap.position.x, $1.position.y - cap.position.y)
            }) else { return }
            target = prey.position
        } else {
            guard let t = me.target,
                  let box = Layout.boxes.first(where: { $0.n == t }) else { return }
            target = Layout.toScene(CGPoint(x: box.rect.midX, y: box.rect.midY))
        }

        var dx = target.x - cap.position.x
        var dy = target.y - cap.position.y
        let dist = hypot(dx, dy)
        guard dist > 1 else { return }
        dx /= dist
        dy /= dist

        // Search for the launch speed whose slide distance best matches.
        // Killers add pace so the hit arrives with momentum.
        let wanted = dist * (me.isKiller ? 1.15 : 1.0)
        var best = minSpeed
        var bestErr = CGFloat.greatestFiniteMagnitude
        var v = minSpeed
        while v <= maxSpeed {
            let err = abs(travelDistance(atLaunchSpeed: v) - wanted)
            if err < bestErr {
                bestErr = err
                best = v
            }
            v += 12 * u
        }

        // Difficulty: noise on power and angle, plus the occasional full flub.
        var speed = best
        var angle = atan2(dy, dx)
        if Double.random(in: 0...1) < difficulty.flubChance {
            speed = CGFloat.random(in: minSpeed...maxSpeed)
            angle += CGFloat.random(in: -0.35...0.35)
        } else {
            speed *= 1 + CGFloat.random(in: -difficulty.powerNoise...difficulty.powerNoise)
            angle += CGFloat.random(in: -difficulty.angleNoise...difficulty.angleNoise)
        }
        speed = min(max(speed, minSpeed * 0.6), maxSpeed) * me.weight.powerFactor

        launch(capID: id,
               direction: CGVector(dx: cos(angle), dy: sin(angle)),
               speed: speed)
    }

    /// Numeric simulation of the damping + rolling-friction slide model.
    private func travelDistance(atLaunchSpeed v0: CGFloat) -> CGFloat {
        var v = v0
        var distance: CGFloat = 0
        var t: CGFloat = 0
        let dt: CGFloat = 1.0 / 60.0
        while v > stopSpeed && t < 10 {
            distance += v * dt
            v -= (capDamping * v + rollingFriction) * dt
            t += dt
        }
        return distance
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

        // Off the screen = off the block. No slack margin: a cap whose center
        // leaves the visible scene resets to Start immediately. (Fixes the V2
        // bug where a cap could rest invisibly in the 70pt off-scene tolerance
        // and soft-lock the game.)
        let world = CGRect(origin: .zero, size: size)
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
        // Safety net: never resolve a turn with an off-screen shooter.
        if !CGRect(origin: .zero, size: size).contains(cap.position) {
            offWorldShooter = true
            resetCapToStart(id: activeID)
        }
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
