import SwiftUI
import UIKit

// MARK: - Player

enum PlayerStatus: Equatable {
    case chasing(target: Int)   // working through boxes 1...13
    case killer                 // cleared 13 — hunting caps
    case eliminated             // took 3 killer hits
}

struct Player: Identifiable, Equatable {
    let id: Int                 // equals its index in the players array
    var name: String
    var colorIndex: Int
    var weight: CapWeight = .welterweight
    var status: PlayerStatus = .chasing(target: 1)
    var hitsTaken: Int = 0

    var isKiller: Bool { status == .killer }
    var isEliminated: Bool { status == .eliminated }
    var target: Int? {
        if case .chasing(let t) = status { return t }
        return nil
    }
}

// MARK: - App phase

enum AppPhase: Equatable {
    case setup
    case playing
    case gameOver(winner: Int)
}

// MARK: - Shot report (scene -> rules engine)

struct ShotReport {
    let playerID: Int
    let victims: [Int]        // distinct opponent ids the shooter's cap contacted
    let offWorld: Bool        // flew past the pavement limit (already reset to Start)
    let outsideBoard: Bool    // resting on pavement, off the chalk square
    let inDeadZone: Bool      // center inside the frame around 13, not squarely in 13
    let landedBox: Int?       // box the cap is *fully* inside (clear of the chalk)
    let touchedLine: Bool     // resting on any chalk line
}

// MARK: - Cap colors

enum CapPalette {
    static let names = ["Red", "Blue", "Green", "Gold", "Purple", "Orange"]

    static let base: [UIColor] = [0xE2574C, 0x57A8DC, 0x63B663, 0xE8C24E, 0xA379D9, 0xE88A4E].map { UIColor(rgb: $0) }
    static let hi:   [UIColor] = [0xF08A80, 0x9FD0EE, 0x9ADF9A, 0xF6DE94, 0xC9AAEF, 0xF6B98C].map { UIColor(rgb: $0) }
    static let dark: [UIColor] = [0xA03328, 0x2D6F9C, 0x3B7A3B, 0xA8862B, 0x6C4A9C, 0xA8571F].map { UIColor(rgb: $0) }

    static func color(_ i: Int) -> Color { Color(base[i % base.count]) }
    static func hiColor(_ i: Int) -> UIColor { hi[i % hi.count] }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - Cap weight classes ("character select")

enum CapWeight: String, CaseIterable, Identifiable {
    case lightweight, welterweight, heavyweight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lightweight:  return "Lightweight"
        case .welterweight: return "Welterweight"
        case .heavyweight:  return "Heavyweight"
        }
    }

    var nickname: String {
        switch self {
        case .lightweight:  return "The Flick"
        case .welterweight: return "The Classic"
        case .heavyweight:  return "The Quarter"
        }
    }

    var emoji: String {
        switch self {
        case .lightweight:  return "🪶"
        case .welterweight: return "🕯"
        case .heavyweight:  return "🪙"
        }
    }

    var flavor: String {
        switch self {
        case .lightweight:  return "Empty cap — flies far, gets smacked around."
        case .welterweight: return "Wax-filled — the balanced standard."
        case .heavyweight:  return "Quarter-loaded — short slides, barely flinches."
        }
    }

    /// Physics mass: recoil dynamics come free from momentum exchange.
    var mass: CGFloat {
        switch self {
        case .lightweight:  return 0.7
        case .welterweight: return 1.0
        case .heavyweight:  return 1.5
        }
    }

    /// Multiplier on launch speed — heavy caps travel less per unit of power.
    var powerFactor: CGFloat {
        switch self {
        case .lightweight:  return 1.15
        case .welterweight: return 1.0
        case .heavyweight:  return 0.85
        }
    }

    var rangePips: Int {
        switch self {
        case .lightweight:  return 5
        case .welterweight: return 3
        case .heavyweight:  return 2
        }
    }

    var stabilityPips: Int {
        switch self {
        case .lightweight:  return 2
        case .welterweight: return 3
        case .heavyweight:  return 5
        }
    }
}

/// One row from the setup screen.
struct PlayerEntry {
    let name: String
    let weight: CapWeight
}
