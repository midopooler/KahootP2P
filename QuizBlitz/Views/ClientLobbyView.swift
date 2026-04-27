import SwiftUI

struct ClientLobbyView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        ZStack {
            KahootBackground()

            VStack(spacing: 20) {
                if let game = vm.clientGame {
                    Text(game.title)
                        .font(.title.bold())
                        .foregroundColor(.white)
                } else {
                    ProgressView().tint(.white)
                    Text("Connecting...")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }

                Divider().background(Color.white.opacity(0.3))

                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(K.gold)
                    Text("\(vm.clientPlayers.count) Players")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.clientPlayers) { player in
                            HStack {
                                Circle()
                                    .fill(K.choiceColors[abs(player.displayName.hashValue) % 4])
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(String(player.displayName.prefix(1)).uppercased())
                                            .font(.headline.bold())
                                            .foregroundColor(.white)
                                    )
                                Text(player.displayName)
                                    .font(.body.bold())
                                    .foregroundColor(.white)
                                if let engine = vm.clientEngine,
                                   player.id?.contains(engine.playerId) == true {
                                    Text("(you)")
                                        .font(.caption)
                                        .foregroundColor(K.gold)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                if vm.p2p?.isConnected == true {
                    HStack(spacing: 8) {
                        Circle().fill(K.green).frame(width: 10, height: 10)
                        Text("Connected! Waiting for host...")
                            .foregroundColor(K.green)
                    }
                } else {
                    Text("Connecting to host...")
                        .foregroundColor(.white.opacity(0.6))
                }

                Button("Leave") { vm.leaveGame() }
                    .foregroundColor(K.red)
                    .padding(.bottom, 16)
            }
            .padding(.top)
        }
        .navigationBarHidden(true)
    }
}
