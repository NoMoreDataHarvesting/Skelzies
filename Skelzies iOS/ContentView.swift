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
    @State private var sidebarOpen = true

    var body: some View {
        ZStack {
            Color(UIColor(rgb: 0x1D1E22)).ignoresSafeArea()

            // Full-screen board. The scene is built to this view's exact
            // aspect ratio, so aspectFit renders edge to edge — no bars.
            GeometryReader { geo in
                if let scene = vm.sceneFor(viewSize: geo.size) {
                    SpriteView(scene: scene, preferredFramesPerSecond: 60)
                } else {
                    Color(UIColor(rgb: 0x1D1E22))
                }
            }
            .ignoresSafeArea()

            // Message banner
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

            // Collapsible leaderboard overlay
            HStack(spacing: 0) {
                Spacer()
                if sidebarOpen {
                    LeaderboardView(vm: vm)
                        .frame(width: 270)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()

            // Sidebar toggle — pinned top-right, always reachable
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { sidebarOpen.toggle() }
                    } label: {
                        Image(systemName: sidebarOpen ? "sidebar.trailing" : "sidebar.leading")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
                    }
                    .padding(.top, 10)
                    .padding(.trailing, sidebarOpen ? 282 : 12)
                }
                Spacer()
            }

            if case .gameOver(let winner) = vm.phase,
               vm.players.indices.contains(winner) {
                GameOverView(winnerName: vm.players[winner].name,
                             isTraditional: vm.mode == .traditional,
                             onHome: { vm.backToSetup() })
            }
        }
    }
}

struct GameOverView: View {
    let winnerName: String
    let isTraditional: Bool
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.yellow)
                Text(isTraditional
                     ? "\(winnerName) runs the board!"
                     : "\(winnerName) is the last cap standing!")
                    .font(.custom("ChalkboardSE-Bold", size: 30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Button(action: onHome) {
                    HStack(spacing: 10) {
                        Image(systemName: "house.fill")
                        Text("Go Home")
                    }
                }
                .buttonStyle(ChalkButton(prominent: true))
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
