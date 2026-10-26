import SwiftUI

@main
struct ShawarmaEmpireApp: App {
    @StateObject private var game = GameController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                game.save()
            } else if game.musicOn && game.scenario == nil {
                Sound.shared.setMusic(true)
            }
        }
    }
}
