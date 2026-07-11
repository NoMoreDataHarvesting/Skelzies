import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var vm = GameViewModel()

    var body: some View {
        Group {
            switch vm.phase {
            case .setup:
                SetupView(vm: vm)
            default:
                GamePlayView(vm: vm)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

struct GamePlayView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color(UIColor(rgb: 0x1D1E22))
                if let scene = vm.scene {
                    SpriteView(scene: scene, preferredFramesPerSecond: 60)
                }
                VStack {
                    Text(vm.message)
                        .font(.custom("ChalkboardSE-Bold", size: 17))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .frame(maxWidth: 640)
                        .padding(.top, 12)
                    Spacer()
                }
                if case .gameOver(let winner) = vm.phase {
                    GameOverView(vm: vm, winnerID: winner)
                }
            }
            LeaderboardView(vm: vm)
                .frame(width: 270)
        }
        .ignoresSafeArea()
    }
}

struct GameOverView: View {
    @ObservedObject var vm: GameViewModel
    let winnerID: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.yellow)
                Text("\(vm.players[winnerID].name) is the last cap standing!")
                    .font(.custom("ChalkboardSE-Bold", size: 30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    Button("Rematch") { vm.restart() }
                        .buttonStyle(ChalkButton(prominent: true))
                    Button("New players") { vm.backToSetup() }
                        .buttonStyle(ChalkButton())
                }
            }
            .padding(30)
        }
    }
}

struct ChalkButton: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("ChalkboardSE-Bold", size: 20))
            .padding(.horizontal, 26)
            .padding(.vertical, 10)
            .background(Capsule().stroke(prominent ? Color.yellow : Color.white.opacity(0.5), lineWidth: 2))
            .foregroundColor(prominent ? .yellow : .white)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
