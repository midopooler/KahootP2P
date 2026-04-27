import Foundation
import CouchbaseLiteSwift
import Combine

final class HostEngine: ObservableObject {
    private let db = DatabaseManager.shared
    private let p2p: P2PService

    @Published var game: Game
    @Published var players: [Player] = []
    @Published var currentQuestionIndex: Int = -1
    @Published var questionState: QuestionState?
    @Published var leaderboard: Leaderboard?

    private var questions: [Question] = []
    private var answerSeqCounter: Int = 0
    private var playerScores: [String: PlayerScore] = [:]
    private var processedAnswerIds: Set<String> = []
    private var questionStartTimes: [Int: UInt64] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(p2p: P2PService, gameTitle: String) {
        self.p2p = p2p
        let joinCode = UUID().uuidString.prefix(6).uppercased()
        self.game = Game(title: gameTitle, joinCode: String(joinCode))
        setupReactiveListeners()
    }

    // MARK: - Reactive listeners (Combine)

    private func setupReactiveListeners() {
        db.collectionChangePublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.handleCollectionChange(change)
            }
            .store(in: &cancellables)
    }

    private func handleCollectionChange(_ change: CollectionChange) {
        guard let gameId = game.id else { return }
        for docId in change.documentIDs {
            guard docId.contains(gameId) else { continue }
            refreshPlayers()
            processIncomingAnswer(docId: docId)
        }
    }

    private func refreshPlayers() {
        guard let gameId = game.id else { return }
        if let updated = try? db.getPlayers(gameId: gameId) {
            self.players = updated
        }
    }

    // MARK: - Game lifecycle

    func startGame() throws {
        guard let gameId = game.id else { return }
        questions = SampleQuestions.generate(gameId: gameId)
        for q in questions {
            try db.save(q)
        }
        game.questionCount = questions.count
        try db.save(game)
        try moveToNextQuestion()
    }

    func moveToNextQuestion() throws {
        guard let gameId = game.id else { return }
        currentQuestionIndex += 1
        answerSeqCounter = 0

        guard currentQuestionIndex < questions.count else {
            try finishGame()
            return
        }

        let question = questions[currentQuestionIndex]
        let startNs = TimingService.currentUptimeNs()
        questionStartTimes[currentQuestionIndex] = startNs

        let timeLimitNs = UInt64(question.timeLimitSeconds) * 1_000_000_000

        let state = QuestionState(
            gameId: gameId,
            currentQuestionId: question.id,
            currentQuestionIndex: currentQuestionIndex,
            phase: .asking,
            questionStartSeq: currentQuestionIndex,
            questionStartHostUptimeNs: startNs,
            closeAtHostUptimeNs: startNs + timeLimitNs
        )
        state.id = "questionState::\(gameId)"
        try db.save(state)
        self.questionState = state

        let qIndex = currentQuestionIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(question.timeLimitSeconds)) { [weak self] in
            guard self?.currentQuestionIndex == qIndex else { return }
            try? self?.closeCurrentQuestion()
        }
    }

    func closeCurrentQuestion() throws {
        guard let state = questionState, state.phase == .asking else { return }

        state.phase = .closed
        try db.save(state)
        self.questionState = state

        rescanAndScore()

        let qIndex = currentQuestionIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard self?.currentQuestionIndex == qIndex else { return }
            self?.rescanAndScore()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard self?.currentQuestionIndex == qIndex else { return }
            self?.rescanAndScore()
        }
    }

    // MARK: - Answer processing

    private func processIncomingAnswer(docId: String) {
        guard let doc = try? db.collection.document(id: docId) else { return }
        let dict = doc.toDictionary()

        guard dict["selectedChoiceIndex"] != nil,
              let questionId = dict["questionId"] as? String else { return }

        guard !processedAnswerIds.contains(docId) else { return }

        guard let qIndex = questions.firstIndex(where: { $0.id == questionId }) else { return }
        guard let startNs = questionStartTimes[qIndex] else { return }

        guard let answer: Answer = try? decodeFromDict(dict) else { return }

        processedAnswerIds.insert(docId)

        let receivedNs = TimingService.currentUptimeNs()
        let question = questions[qIndex]
        scoreAnswer(answer, question: question, startNs: startNs, receivedNs: receivedNs)

        if questionState?.phase == .closed {
            try? computeScoresForCurrentQuestion()
        }
    }

    private func rescanAndScore() {
        guard let gameId = game.id,
              let qId = questionState?.currentQuestionId,
              let qIndex = questions.firstIndex(where: { $0.id == qId }),
              let startNs = questionStartTimes[qIndex] else { return }

        let question = questions[qIndex]
        let answers = (try? db.getAnswers(gameId: gameId, questionId: qId)) ?? []

        var newlyScored = false
        for answer in answers {
            let answerId = answer.id ?? "answer::\(gameId)::\(qId)::\(answer.playerId)"
            guard !processedAnswerIds.contains(answerId) else { continue }
            processedAnswerIds.insert(answerId)

            let receivedNs = TimingService.currentUptimeNs()
            scoreAnswer(answer, question: question, startNs: startNs, receivedNs: receivedNs)
            newlyScored = true
        }

        if newlyScored {
            try? computeScoresForCurrentQuestion()
        }
    }

    // MARK: - Score a single answer

    private func scoreAnswer(_ answer: Answer, question: Question, startNs: UInt64, receivedNs: UInt64) {
        answerSeqCounter += 1
        let isCorrect = answer.selectedChoiceIndex == question.correctChoiceIndex

        let timeDelta = TimingService.elapsedSeconds(from: startNs, to: receivedNs)
        let clampedDelta = min(timeDelta, Double(question.timeLimitSeconds))
        let timeBonus = max(0, 1.0 - (clampedDelta / Double(question.timeLimitSeconds)))
        let points = isCorrect ? max(100, Int(1000.0 * timeBonus)) : 0

        print("[HostEngine] Score: player=\(answer.playerId.prefix(8)) correct=\(isCorrect) delta=\(String(format: "%.2f", timeDelta))s bonus=\(String(format: "%.2f", timeBonus)) pts=\(points)")

        let result = AnswerResult(
            gameId: answer.gameId,
            questionId: answer.questionId,
            playerId: answer.playerId,
            isCorrect: isCorrect,
            points: points,
            hostReceivedSeq: answerSeqCounter,
            hostReceivedUptimeNs: receivedNs
        )
        result.id = "answerResult::\(answer.gameId)::\(answer.questionId)::\(answer.playerId)"
        try? db.save(result)

        updatePlayerScore(playerId: answer.playerId, additionalPoints: points, isCorrect: isCorrect)
    }

    // MARK: - Player scores

    private func updatePlayerScore(playerId: String, additionalPoints: Int, isCorrect: Bool) {
        guard let gameId = game.id else { return }
        if let score = playerScores[playerId] {
            score.totalPoints += additionalPoints
            score.correctCount += isCorrect ? 1 : 0
            try? db.save(score)
        } else {
            let displayName = players.first(where: {
                $0.id?.contains(playerId) == true
            })?.displayName ?? "Player"
            let score = PlayerScore(
                gameId: gameId,
                playerId: playerId,
                displayName: displayName,
                totalPoints: additionalPoints,
                correctCount: isCorrect ? 1 : 0
            )
            score.id = "score::\(gameId)::\(playerId)"
            playerScores[playerId] = score
            try? db.save(score)
        }
    }

    private func computeScoresForCurrentQuestion() throws {
        guard let gameId = game.id else { return }
        let sorted = Array(playerScores.values).sorted { $0.totalPoints > $1.totalPoints }
        for (i, score) in sorted.enumerated() {
            score.rank = i + 1
            try db.save(score)
        }

        let entries = sorted.map { score in
            LeaderboardEntry(
                playerId: score.playerId,
                displayName: score.displayName,
                totalPoints: score.totalPoints,
                rank: score.rank
            )
        }

        let lb = Leaderboard(gameId: gameId, entries: entries)
        lb.id = "leaderboard::\(gameId)"
        try db.save(lb)
        self.leaderboard = lb

        print("[HostEngine] Leaderboard: \(entries.map { "\($0.displayName)=\($0.totalPoints)" }.joined(separator: ", "))")
    }

    // MARK: - Finish

    private func finishGame() throws {
        game.phase = .finished
        try db.save(game)

        if let state = questionState {
            state.phase = .finished
            try db.save(state)
            self.questionState = state
        }

        rescanAndScore()
        try computeScoresForCurrentQuestion()
    }

    func cleanup() {
        cancellables.removeAll()
        p2p.disconnect()
    }

    // MARK: - Helpers

    private func decodeFromDict<T: Decodable>(_ dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
