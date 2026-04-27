import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                KahootBackground()

                VStack(spacing: 28) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("KahootP2P")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 3)

                        Text("Offline P2P Quiz")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    VStack(spacing: 16) {
                        TextField("", text: $vm.playerName, prompt: Text("Enter your name").foregroundColor(.white.opacity(0.5)))
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )

                        KahootButton(title: "Host a Game", color: K.green) {
                            vm.createGame()
                        }

                        KahootButton(title: "Join a Game", color: K.blue) {
                            vm.browseForGames()
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: .constant(vm.screen == .hostLobby)) {
                HostLobbyView().environmentObject(vm)
            }
            .navigationDestination(isPresented: .constant(vm.screen == .clientBrowse)) {
                ClientBrowseView().environmentObject(vm)
            }
            .navigationDestination(isPresented: .constant(vm.screen == .clientLobby)) {
                ClientLobbyView().environmentObject(vm)
            }
            .navigationDestination(isPresented: .constant(vm.screen == .playing)) {
                if vm.hostEngine != nil {
                    HostPlayView().environmentObject(vm)
                } else {
                    ClientPlayView().environmentObject(vm)
                }
            }
            .navigationDestination(isPresented: .constant(vm.screen == .results)) {
                ResultsView().environmentObject(vm)
            }
        }
    }
}
