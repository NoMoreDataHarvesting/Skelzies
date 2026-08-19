import SwiftUI
import Combine
import SpriteKit

final class GameViewModel: ObservableObject {

    @Published var players: [Player] = []
    @Published var currentIndex = 0
    @Published var message = "Chalk it up."
    @Published var phase: AppPhase = .setup
    @Published var mode: GameMode = .traditional

    var scene: GameScene?

    var anyKillers: Bool { players.contains { $0.isKiller } }

    /// Turn order starting with the current player; eliminated players sink to the bottom.
    var turnOrdered: [Player] {
        guard !players.isEmpty else { return [] }
        let n = players.count
        let rotated = (0..<n).map { players[(currentIndex + $0) % n] }
        return rotated.filter { !$0.isEliminated } + rotated.filter { $0.isEliminated }
    }

    // MARK: - Lifecycle

    func startGame(entries: [PlayerEntry], mode: GameMode) {
        self.mode = mode
        players = entries.enumerated().map { index, entry in
            Player(id: index,
                   name: entry.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Player \(index + 1)" : entry.name,
                   colorIndex: index,
                   weight: entry.weight,
                   control: entry.control)
        }
        currentIndex = 0
        scene = nil   // the view builds the scene sized to the actual display

        message = "\(players[0].name) starts — flick for box 1."
        phase = .playing
    }

    /// Called by the view once real geometry is known. The scene is built to
    /// the display's aspect ratio, so `.aspectFit` renders with zero
    /// letterbox bars and the board dominates the screen.
    func sceneFor(viewSize: CGSize) -> GameScene? {
        if let scene { return scene }
        guard phase != .setup, viewSize.width > 10, viewSize.height > 10 else { return nil }
        let aspect = min(max(viewSize.width / viewSize.height, 1.25), 1.55)
        let size = CGSize(width: (1000 * aspect).rounded(), height: 1000)
        Layout.configure(sceneSize: size)
        let newScene = GameScene(size: size)
        newScene.scaleMode = .aspectFit
        newScene.vm = self
        scene = newScene
        return newScene
    }

    func restart() {
        startGame(entries: players.map { PlayerEntry(name: $0.name, weight: $0.weight, control: $0.control) }, mode: mode)
    }

    func backToSetup() {
        // Do NOT clear `players` here: the win overlay reads the winner's name
        // and may still be on screen for one more render pass — emptying the
        // array mid-frame crashed the Go Home button. startGame() rebuilds the
        // roster from scratch, so nothing stale survives into the next game.
        scene = nil
        phase = .setup
    }

    // MARK: - Turn resolution

    func resolve(_ report: ShotReport) {
        guard phase == .playing, report.playerID == currentIndex else { return }
        let name = players[currentIndex].name
        var extraTurn = false

        if players[currentIndex].isKiller {
            // ---- Killer turn: every contacted cap takes a hit; 3 hits = KO ----
            var struck = false
            for victim in report.victims where victim != currentIndex && !players[victim].isEliminated {
                players[victim].hitsTaken += 1
                struck = true
                if players[victim].hitsTaken >= 3 {
                    players[victim].status = .eliminated
                    scene?.removeCap(id: victim)
                    message = "☠️ \(name) knocks out \(players[victim].name)!"
                } else {
                    message = "\(name) tags \(players[victim].name) — hit \(players[victim].hitsTaken) of 3."
                }
            }
            if report.offWorld { scene?.resetCapToStart(id: currentIndex) }
            extraTurn = struck
            if struck {
                message += " Shoot again."
            } else {
                message = report.offWorld
                    ? "\(name) flew off the block — back to Start."
                    : "\(name) swings and misses."
            }
        } else {
            // ---- Chaser turn: land squarely, in order, or the turn is over ----
            if report.offWorld {
                scene?.resetCapToStart(id: currentIndex)
                message = "\(name) flew off the block — back to Start."
            } else if report.inDeadZone {
                let t = max(1, (players[currentIndex].target ?? 1) - 1)
                players[currentIndex].status = .chasing(target: t)
                message = "☠️ Dead zone! \(name) drops back to box \(t)."
            } else if let box = report.landedBox, box == players[currentIndex].target {
                if box == 13 {
                    if mode == .traditional {
                        phase = .gameOver(winner: currentIndex)
                        message = "🏆 \(name) runs the board — 1 through 13!"
                        scene?.endInput()
                        return
                    }
                    players[currentIndex].status = .killer
                    scene?.markKiller(id: currentIndex)
                    message = "👑 \(name) clears 13 — KILLER! Hunt the other caps."
                } else {
                    players[currentIndex].status = .chasing(target: box + 1)
                    message = "\(name) sinks box \(box) — go again for \(box + 1)."
                }
                extraTurn = true
            } else if report.touchedLine {
                message = "\(name) clipped the chalk — turn over."
            } else if report.outsideBoard {
                message = "\(name) slid off the board."
            } else if let box = report.landedBox {
                message = "\(name) parked in box \(box) — wrong number."
            } else {
                message = "No dice for \(name)."
            }
        }

        // ---- Win check: last cap standing ----
        let alive = players.filter { !$0.isEliminated }
        if alive.count == 1 {
            phase = .gameOver(winner: alive[0].id)
            message = "🏆 \(alive[0].name) is the last cap standing!"
            scene?.endInput()
            return
        }

        if !extraTurn { advanceTurn() }
        scene?.beginTurn(for: currentIndex)
    }

    private func advanceTurn() {
        let n = players.count
        var i = currentIndex
        repeat { i = (i + 1) % n } while players[i].isEliminated
        currentIndex = i
        let p = players[i]
        if p.isKiller {
            message += " \(p.name)'s turn — hunting caps."
        } else {
            message += " \(p.name)'s turn — box \(p.target ?? 1)."
        }
    }
}
