import SwiftUI
import UIKit

/// Landscape-only enforcement, layer 1: the app-level orientation mask.
/// NOTE: on iPad this mask is only honored when "Requires Full Screen" is
/// enabled on the target (UIRequiresFullScreen = YES) — see the
/// Landscape-Lock-Setup guide for the one checkbox you must flip in Xcode.
final class OrientationLock: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }
}

@main
struct SkelziesApp: App {
    @UIApplicationDelegateAdaptor(OrientationLock.self) private var orientationLock
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear { Self.enforceLandscape() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { Self.enforceLandscape() }
        }
    }

    /// Landscape-only enforcement, layer 2: actively rotate any scene that
    /// came up in portrait (e.g. cold boot with the iPad held vertically)
    /// into landscape, and re-assert whenever the app returns to foreground.
    ///
    /// Explicitly main-actor isolated: it touches UIApplication.shared and the
    /// window scene, so it must not be called from anywhere else. Call it from
    /// inside a closure rather than passing it as a function reference — a
    /// reference would have to cross into a nonisolated context to satisfy
    /// onAppear(perform:), which is what the compiler warns about.
    @MainActor
    static func enforceLandscape() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            windowScene.keyWindow?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
