import SwiftUI

struct HostLobbyView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        ZStack {
            KahootBackground()

            VStack(spacing: 20) {
                if let engine = vm.hostEngine {
                    Text(engine.game.title)
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Text(engine.game.joinCode)
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(K.gold)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)

                    Text("Game PIN")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Divider().background(Color.white.opacity(0.3))

                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(K.gold)
                        Text("\(vm.hostPlayers.count) Players")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.hostPlayers) { player in
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

                    if !vm.hostPlayers.isEmpty {
                        KahootButton(title: "Start (\(vm.hostPlayers.count) players)", color: K.green) {
                            vm.hostStartGame()
                        }
                        .padding(.horizontal, 32)
                    } else {
                        Text("Waiting for players...")
                            .foregroundColor(.white.opacity(0.6))
                            .padding()
                    }

                    Button("Cancel") { vm.leaveGame() }
                        .foregroundColor(K.red)
                        .padding(.bottom, 8)
                }
            }
            .padding(.top)
        }
        .navigationBarHidden(true)
    }
}
