import SwiftUI

@main
struct AssemblyEmpireApp: App {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.save() }
        }
    }
}
