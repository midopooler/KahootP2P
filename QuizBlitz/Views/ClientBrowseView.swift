import SwiftUI

struct ClientBrowseView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        ZStack {
            KahootBackground()

            VStack(spacing: 24) {
                Text("Find a Game")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .padding(.top, 24)

                if vm.discoveredHosts.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Searching nearby...")
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 12)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.discoveredHosts, id: \.name) { host in
                                Button {
                                    vm.joinHost(name: host.name, host: host.host, port: host.port)
                                } label: {
                                    HStack {
                                        Image(systemName: "wifi")
                                            .font(.title2)
                                            .foregroundColor(K.green)
                                        VStack(alignment: .leading) {
                                            Text(host.name)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }
                                        Spacer()
                                        Text("JOIN")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(K.green)
                                            .foregroundColor(.white)
                                            .cornerRadius(20)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Button("Cancel") { vm.leaveGame() }
                    .foregroundColor(K.red)
                    .padding(.bottom, 16)
            }
        }
        .navigationBarHidden(true)
    }
}
