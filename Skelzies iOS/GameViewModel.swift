import SwiftUI
import Combine

final class GameViewModel: ObservableObject {

    @Published var players: [Player] = []
    @Published var currentIndex = 0
    @Published var message = "Chalk it up."
    @Published var phase: AppPhase = .setup

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

    func startGame(names: [String]) {
        players = names.enumerated().map { index, name in
            Player(id: index,
                   name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Player \(index + 1)" : name,
                   colorIndex: index)
        }
        currentIndex = 0

        let newScene = GameScene(size: Layout.sceneSize)
        newScene.scaleMode = .aspectFit
        newScene.vm = self
        scene = newScene

        message = "\(players[0].name) starts — flick for box 1."
        phase = .playing
    }

    func restart() {
        startGame(names: players.map(\.name))
    }

    func backToSetup() {
        scene = nil
        players = []
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
