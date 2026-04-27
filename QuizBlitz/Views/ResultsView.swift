import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        ZStack {
            KahootBackground()

            VStack(spacing: 20) {
                Text("Final Results")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(K.gold)
                    .padding(.top, 32)

                if let lb = vm.hostEngine?.leaderboard ?? vm.clientEngine?.leaderboard {
                    LeaderboardListView(
                        entries: lb.entries,
                        highlightPlayerId: vm.clientEngine?.playerId
                    )
                    .padding(.horizontal)
                }

                Spacer()

                KahootButton(title: "Back to Home", color: K.red) {
                    vm.leaveGame()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }
        }
        .navigationBarHidden(true)
    }
}
