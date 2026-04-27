import Foundation
import Combine

enum AppScreen {
    case home
    case hostLobby
    case clientBrowse
    case clientLobby
    case playing
    case results
}

final class GameViewModel: ObservableObject {
    @Published var screen: AppScreen = .home
    @Published var playerName: String = ""
    @Published var gameTitle: String = "Quiz Game"

    @Published var p2p: P2PService?
    @Published var hostEngine: HostEngine?
    @Published var clientEngine: ClientEngine?
    @Published var discoveredHosts: [(name: String, host: String, port: Int)] = []
    @Published var hostPlayers: [Player] = []
    @Published var clientGame: Game?
    @Published var clientPlayers: [Player] = []
    @Published var clientQuestionState: QuestionState?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Host flow

    func createGame() {
        do {
            try DatabaseManager.shared.initialize()
        } catch {
            print("[GameViewModel] DB init failed: \(error)")
            return
        }

        let service = P2PService(
            database: DatabaseManager.shared.database,
            collection: DatabaseManager.shared.collection
        )
        self.p2p = service

        let engine = HostEngine(p2p: service, gameTitle: gameTitle)
        self.hostEngine = engine

        do {
            try DatabaseManager.shared.save(engine.game)
            guard let gameId = engine.game.id else {
                print("[GameViewModel] Game ID not assigned")
                return
            }
            try service.startHosting(gameId: gameId)
        } catch {
            print("[GameViewModel] Failed to start hosting: \(error)")
            return
        }

        engine.$players
            .receive(on: DispatchQueue.main)
            .sink { [weak self] players in
                self?.hostPlayers = players
            }
            .store(in: &cancellables)

        screen = .hostLobby
    }

    func hostStartGame() {
        do {
            try hostEngine?.startGame()
            screen = .playing
        } catch {
            print("[GameViewModel] Failed to start game: \(error)")
        }
    }

    func hostNextQuestion() {
        do {
            try hostEngine?.moveToNextQuestion()
        } catch {
            print("[GameViewModel] Failed to move to next question: \(error)")
        }
    }

    // MARK: - Client flow

    func browseForGames() {
        do {
            try DatabaseManager.shared.initialize()
        } catch {
            print("[GameViewModel] DB init failed: \(error)")
            return
        }

        let service = P2PService(
            database: DatabaseManager.shared.database,
            collection: DatabaseManager.shared.collection
        )
        self.p2p = service

        let name = playerName.isEmpty ? "Player" : playerName
        let engine = ClientEngine(p2p: service, displayName: name)
        self.clientEngine = engine

        service.startBrowsing()

        service.$discoveredHosts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hosts in
                self?.discoveredHosts = hosts
            }
            .store(in: &cancellables)

        screen = .clientBrowse
    }

    func joinHost(name: String, host: String, port: Int) {
        p2p?.connectToHost(host: host, port: port)

        if let engine = clientEngine {
            engine.$game
                .receive(on: DispatchQueue.main)
                .sink { [weak self] game in self?.clientGame = game }
                .store(in: &cancellables)
            engine.$players
                .receive(on: DispatchQueue.main)
                .sink { [weak self] players in self?.clientPlayers = players }
                .store(in: &cancellables)
            engine.$questionState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.clientQuestionState = state
                    if state?.phase == .asking {
                        self?.screen = .playing
                    }
                }
                .store(in: &cancellables)
        }

        screen = .clientLobby
    }

    // MARK: - Cleanup

    func leaveGame() {
        hostEngine?.cleanup()
        clientEngine?.cleanup()
        p2p?.disconnect()
        hostEngine = nil
        clientEngine = nil
        p2p = nil
        try? DatabaseManager.shared.clearAllData()
        screen = .home
    }
}
