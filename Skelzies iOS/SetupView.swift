import SwiftUI

struct SetupView: View {
    @ObservedObject var vm: GameViewModel

    @State private var mode: GameMode = .traditional
    @State private var count = 2
    @State private var names = (1...6).map { "Player \($0)" }
    @State private var weights = Array(repeating: CapWeight.welterweight, count: 6)

    var body: some View {
        ZStack {
            Color(UIColor(rgb: 0x1D1E22)).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("SKELZIES")
                    .font(.custom("ChalkboardSE-Bold", size: 48))
                    .kerning(6)
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(-1.5))
                    .padding(.top, 8)
                Text("NYC EDITION")
                    .font(.caption)
                    .kerning(4)
                    .foregroundColor(.yellow.opacity(0.9))

                // Game mode select
                HStack(spacing: 12) {
                    ForEach(GameMode.allCases) { m in
                        Button { mode = m } label: {
                            VStack(spacing: 3) {
                                Text(m.title)
                                    .font(.custom("ChalkboardSE-Bold", size: 18))
                                    .foregroundColor(mode == m ? .yellow : .white)
                                Text(m.subtitle.uppercased())
                                    .font(.system(size: 9, weight: .heavy))
                                    .kerning(1.5)
                                    .foregroundColor(.gray)
                                Text(m.blurb)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 26)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(width: 250)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(mode == m ? Color.yellow : Color.white.opacity(0.25),
                                            lineWidth: mode == m ? 2 : 1)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(mode == m ? Color.yellow.opacity(0.10) : Color.clear))
                            )
                        }
                    }
                }

                HStack(spacing: 12) {
                    Text("Players")
                        .font(.custom("ChalkboardSE-Bold", size: 20))
                        .foregroundColor(.white)
                    ForEach(2...6, id: \.self) { n in
                        Button("\(n)") { count = n }
                            .font(.custom("ChalkboardSE-Bold", size: 22))
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .strokeBorder(count == n ? Color.yellow : Color.white.opacity(0.4), lineWidth: 2)
                                    .background(Circle().fill(count == n ? Color.yellow.opacity(0.15) : Color.clear))
                            )
                            .foregroundColor(count == n ? .yellow : .white)
                    }
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Roster: name + cap pick per player
                        VStack(spacing: 8) {
                            ForEach(0..<count, id: \.self) { i in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(CapPalette.color(i))
                                        .frame(width: 22, height: 22)
                                        .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                                    TextField("Player \(i + 1)", text: $names[i])
                                        .font(.custom("ChalkboardSE-Bold", size: 16))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                                        .autocorrectionDisabled()
                                    HStack(spacing: 6) {
                                        ForEach(CapWeight.allCases) { w in
                                            Button { weights[i] = w } label: {
                                                Text(w.emoji)
                                                    .font(.system(size: 17))
                                                    .frame(width: 40, height: 34)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(weights[i] == w ? Color.yellow : Color.white.opacity(0.25),
                                                                    lineWidth: weights[i] == w ? 2 : 1)
                                                            .background(RoundedRectangle(cornerRadius: 8)
                                                                .fill(weights[i] == w ? Color.yellow.opacity(0.12) : Color.clear))
                                                    )
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: 560)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Character-select legend
                        Text("PICK YOUR CAP")
                            .font(.caption2)
                            .kerning(2.5)
                            .foregroundColor(.gray)
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(CapWeight.allCases) { w in
                                VStack(spacing: 4) {
                                    Text("\(w.emoji) \(w.label)")
                                        .font(.custom("ChalkboardSE-Bold", size: 14))
                                        .foregroundColor(.white)
                                    Text("\u{201C}\(w.nickname)\u{201D}")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text(w.flavor)
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .frame(height: 28)
                                    pipRow("RANGE", w.rangePips)
                                    pipRow("STABILITY", w.stabilityPips)
                                }
                                .padding(10)
                                .frame(width: 176)
                                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                Button {
                    let entries = (0..<count).map { PlayerEntry(name: names[$0], weight: weights[$0]) }
                    vm.startGame(entries: entries, mode: mode)
                } label: {
                    Text("Chalk it up")
                }
                .buttonStyle(ChalkButton(prominent: true))

                Text("Land squarely, in order, 1 to 13 — clip the chalk and your turn is over.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
        }
    }

    private func pipRow(_ label: String, _ filled: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
                .frame(width: 54, alignment: .trailing)
            HStack(spacing: 2) {
                ForEach(0..<5) { k in
                    Circle()
                        .fill(k < filled ? Color.yellow : Color.white.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
}
