import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ON DECK")
                .font(.caption)
                .kerning(2.5)
                .foregroundColor(.gray)
                .padding(.top, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(vm.turnOrdered.enumerated()), id: \.element.id) { slot, player in
                        PlayerCard(player: player, slot: slot, showPips: vm.anyKillers)
                    }
                }
            }

            Spacer(minLength: 0)

            Button("Go Home") { vm.backToSetup() }
                .font(.custom("ChalkboardSE-Bold", size: 15))
                .foregroundColor(.gray)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .background(Color(UIColor(rgb: 0x141417)))
    }
}

struct PlayerCard: View {
    let player: Player
    let slot: Int
    let showPips: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(CapPalette.color(player.colorIndex))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 1.5))
                if player.isEliminated {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(.custom("ChalkboardSE-Bold", size: 16))
                        .foregroundColor(player.isEliminated ? .gray : .white)
                        .lineLimit(1)
                    Text(player.weight.emoji)
                        .font(.system(size: 11))
                    if player.isCPU {
                        Image(systemName: "cpu")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                if player.isEliminated {
                    Text("KNOCKED OUT")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.red.opacity(0.8))
                } else if slot == 0 {
                    badge("NOW", color: .yellow)
                } else if slot == 1 {
                    badge("NEXT", color: .gray)
                }
            }

            Spacer(minLength: 4)

            VStack(spacing: 4) {
                statusIcon
                if showPips && !player.isEliminated {
                    HStack(spacing: 3) {
                        ForEach(0..<3) { k in
                            Circle()
                                .fill(k < player.hitsTaken ? Color.red : Color.white.opacity(0.15))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(slot == 0 && !player.isEliminated ? 0.06 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(slot == 0 && !player.isEliminated ? Color.yellow : Color.white.opacity(0.18),
                                lineWidth: slot == 0 && !player.isEliminated ? 2 : 1)
                )
        )
        .opacity(player.isEliminated ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.3), value: slot)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .kerning(1)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().stroke(color.opacity(0.7), lineWidth: 1))
    }

    @ViewBuilder
    private var statusIcon: some View {
        if player.isEliminated {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(.red)
        } else if player.isKiller {
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
        } else {
            VStack(spacing: 0) {
                Text("BOX")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                Text("\(player.target ?? 1)")
                    .font(.custom("ChalkboardSE-Bold", size: 24))
                    .foregroundColor(.yellow)
            }
        }
    }
}
