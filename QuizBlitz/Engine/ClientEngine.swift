import Foundation
import CouchbaseLiteSwift
import Combine

final class ClientEngine: ObservableObject {
    private let db = DatabaseManager.shared
    private let p2p: P2PService
    let playerId: String
    let displayName: String

    @Published var game: Game?
    @Published var players: [Player] = []
    @Published var questions: [Question] = []
    @Published var questionState: QuestionState?
    @Published var currentQuestion: Question?
    @Published var lastResult: AnswerResult?
    @Published var leaderboard: Leaderboard?
    @Published var hasAnsweredCurrent = false

    private var cancellables = Set<AnyCancellable>()
    private var lastKnownQuestionId: String?

    init(p2p: P2PService, displayName: String) {
        self.p2p = p2p
        self.playerId = UUID().uuidString
        self.displayName = displayName

        setupReactiveListeners()
    }

    // MARK: - Reactive listeners (Combine)

    private func setupReactiveListeners() {
        db.collectionChangePublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshState()
            }
            .store(in: &cancellables)

        p2p.onDocumentsReplicated = { [weak self] in
            DispatchQueue.main.async {
                self?.refreshState()
            }
        }
    }

    // MARK: - Register player

    func registerPlayer(gameId: String) {
        let player = Player(gameId: gameId, displayName: displayName)
        player.id = "player::\(gameId)::\(playerId)"
        try? db.save(player)
    }

    // MARK: - Submit answer

    func submitAnswer(choiceIndex: Int) {
        guard let state = questionState,
              let questionId = state.currentQuestionId,
              let gameId = state.gameId as String?,
              state.phase == .asking,
              !hasAnsweredCurrent else { return }

        let answer = Answer(
            gameId: gameId,
            questionId: questionId,
            playerId: playerId,
            selectedChoiceIndex: choiceIndex,
            clientCreatedAtUptimeNs: TimingService.currentUptimeNs()
        )
        answer.id = "answer::\(gameId)::\(questionId)::\(playerId)"

        do {
            try db.save(answer)
            self.hasAnsweredCurrent = true
        } catch {
            print("[ClientEngine] Failed to submit answer: \(error)")
        }
    }

    // MARK: - State refresh (driven by replication + Combine)

    func refreshState() {
        refreshGame()
        refreshPlayers()
        refreshQuestions()
        refreshQuestionState()
        refreshLeaderboard()
        refreshLastResult()
    }

    private func refreshGame() {
        guard game == nil else { return }
        do {
            let games = try db.queryAll(Game.self, where: "title IS NOT MISSING AND joinCode IS NOT MISSING AND phase IS NOT MISSING")
            print("[ClientEngine] refreshGame: found \(games.count) games")
            if let g = games.first {
                print("[ClientEngine] Found game: id=\(g.id ?? "nil") title=\(g.title)")
                self.game = g
                registerPlayer(gameId: g.id ?? "")
            }
        } catch {
            print("[ClientEngine] refreshGame error: \(error)")
        }
    }

    private func refreshPlayers() {
        guard let gameId = game?.id else { return }
        if let updated = try? db.getPlayers(gameId: gameId) {
            self.players = updated
        }
    }

    private func refreshQuestions() {
        guard let gameId = game?.id else { return }
        if let updated = try? db.getQuestions(gameId: gameId), !updated.isEmpty {
            self.questions = updated
        }
    }

    private func refreshQuestionState() {
        guard let gameId = game?.id else { return }
        if let state = try? db.getQuestionState(gameId: gameId) {
            let questionChanged = state.currentQuestionId != lastKnownQuestionId
            self.questionState = state
            if questionChanged {
                self.hasAnsweredCurrent = false
                self.lastResult = nil
                self.lastKnownQuestionId = state.currentQuestionId
            }
            if let qId = state.currentQuestionId {
                self.currentQuestion = self.questions.first { $0.id == qId }
            }
        }
    }

    private func refreshLeaderboard() {
        guard let gameId = game?.id else { return }
        if let lb = try? db.getLeaderboard(gameId: gameId) {
            self.leaderboard = lb
        }
    }

    private func refreshLastResult() {
        guard let gameId = game?.id,
              let qId = questionState?.currentQuestionId else { return }
        let resultDocId = "answerResult::\(gameId)::\(qId)::\(playerId)"
        if let result = try? db.get(id: resultDocId, as: AnswerResult.self) {
            self.lastResult = result
        }
    }

    func cleanup() {
        cancellables.removeAll()
        p2p.disconnect()
    }
}
