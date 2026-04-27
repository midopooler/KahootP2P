import SwiftUI

@main
struct KahootP2PApp: App {
    @StateObject private var gameViewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(gameViewModel)
        }
    }
}
